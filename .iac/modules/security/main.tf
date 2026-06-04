# ---------------------------------------------------------------------------
# Security Module
# Creates:
#   - GuardDuty detector
#   - CloudTrail (account-wide, stored in S3)
#   - AWS Config recorder + baseline rules
#   - SSM Parameter Store entries for key infra outputs
#   - S3 bucket for CloudTrail logs with lifecycle policy
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.client_name}-${var.environment}"
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

# ── AWS Config ────────────────────────────────────────────────────────────────

resource "aws_config_configuration_recorder" "main" {
  count    = var.create_account_security ? 1 : 0
  name     = "${local.name_prefix}-config-recorder"
  role_arn = var.create_account_security ? aws_iam_role.config.arn : ""

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_s3_bucket" "config" {
  bucket        = "${local.name_prefix}-config-${var.aws_account_id}"
  force_destroy = true

  tags = {
    Name = "${local.name_prefix}-config"
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.config.arn
      },
      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config.arn}/AWSLogs/${var.aws_account_id}/Config/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

resource "aws_config_delivery_channel" "main" {
  count          = var.create_account_security ? 1 : 0
  name           = "${local.name_prefix}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config.bucket
  depends_on     = [aws_config_configuration_recorder.main, aws_s3_bucket_policy.config]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.create_account_security ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main[0]]
}

# IAM role for Config
resource "aws_iam_role" "config" {
  name = "${local.name_prefix}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Baseline Config Rules
resource "aws_config_config_rule" "root_mfa" {
  name        = "${local.name_prefix}-root-mfa-enabled"
  description = "Checks whether the root user has MFA enabled."

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.main[0]]
}

resource "aws_config_config_rule" "iam_password_policy" {
  name        = "${local.name_prefix}-iam-password-policy"
  description = "Checks whether the account password policy meets requirements."

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  input_parameters = jsonencode({
    RequireUppercaseCharacters = "true"
    RequireLowercaseCharacters = "true"
    RequireSymbols             = "true"
    RequireNumbers             = "true"
    MinimumPasswordLength      = "14"
    PasswordReusePrevention    = "24"
    MaxPasswordAge             = "90"
  })

  depends_on = [aws_config_configuration_recorder_status.main[0]]
}

resource "aws_config_config_rule" "s3_public_access" {
  name        = "${local.name_prefix}-s3-no-public-access"
  description = "Checks that S3 buckets have public access blocked."

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.main[0]]
}

resource "aws_config_config_rule" "eks_secrets_encrypted" {
  name        = "${local.name_prefix}-eks-secrets-encrypted"
  description = "Checks that EKS clusters have secrets encryption enabled."

  source {
    owner             = "AWS"
    source_identifier = "EKS_SECRETS_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder_status.main[0]]
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
