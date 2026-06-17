# ---------------------------------------------------------------------------
# Security Module
# Creates:
#   - GuardDuty detector (optional, controlled by create_account_security)
#   - CloudTrail (account-wide, stored in S3)
#   - SSM Parameter Store entries for key infra outputs
#   - S3 bucket for CloudTrail logs with lifecycle policy
# ---------------------------------------------------------------------------

locals {
  name_prefix                 = "${var.client_name}-${var.environment}"
  create_self_signed_alb_cert = var.existing_alb_certificate_arn == "" && var.create_self_signed_alb_certificate
}

# ── GuardDuty ─────────────────────────────────────────────────────────────────

resource "aws_guardduty_detector" "main" {
  count  = var.create_account_security ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name = "${local.name_prefix}-guardduty"
  }
}

# ── CloudTrail ────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${local.name_prefix}-cloudtrail-${var.aws_account_id}"
  force_destroy = true # set false in production

  tags = {
    Name = "${local.name_prefix}-cloudtrail"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = 365
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${var.aws_account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

resource "aws_cloudtrail" "main" {
  name                          = "${local.name_prefix}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${var.tf_state_bucket}/"]
    }
  }

  tags = {
    Name = "${local.name_prefix}-cloudtrail"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ── SSM Parameter Store ───────────────────────────────────────────────────────
# Key outputs stored here so pipelines can read them without Terraform state access

resource "aws_ssm_parameter" "aws_region" {
  name  = "/${var.client_name}/infra/aws_region"
  type  = "String"
  value = var.aws_region
}

resource "aws_ssm_parameter" "aws_account_id" {
  name  = "/${var.client_name}/infra/aws_account_id"
  type  = "String"
  value = var.aws_account_id
}

# ── ALB HTTPS Certificate (self-signed fallback for test environments) ───────

resource "tls_private_key" "alb_https" {
  count     = local.create_self_signed_alb_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_https" {
  count           = local.create_self_signed_alb_cert ? 1 : 0
  private_key_pem = tls_private_key.alb_https[0].private_key_pem

  subject {
    common_name  = var.self_signed_alb_cert_common_name
    organization = "SWH Platform"
  }

  dns_names = [var.self_signed_alb_cert_common_name]

  validity_period_hours = 24 * 365
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb_https_imported" {
  count             = local.create_self_signed_alb_cert ? 1 : 0
  private_key       = tls_private_key.alb_https[0].private_key_pem
  certificate_body  = tls_self_signed_cert.alb_https[0].cert_pem
  certificate_chain = tls_self_signed_cert.alb_https[0].cert_pem

  tags = {
    Name = "${local.name_prefix}-alb-self-signed"
  }
}

locals {
  alb_certificate_arn = var.existing_alb_certificate_arn != "" ? var.existing_alb_certificate_arn : try(aws_acm_certificate.alb_https_imported[0].arn, "")
}

resource "aws_ssm_parameter" "alb_certificate_arn" {
  name  = "/${var.client_name}/infra/alb_certificate_arn"
  type  = "String"
  value = local.alb_certificate_arn
}
