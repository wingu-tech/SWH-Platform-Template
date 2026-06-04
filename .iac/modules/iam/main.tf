# ---------------------------------------------------------------------------
# IAM Module
# Creates:
#   - GitHub Actions OIDC provider + cicd role (trust: this repo only)
#   - Roles:  admin, developer, readonly, cicd
#   - Groups: admins, developers, readonly (map to roles via assume-role policy)
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.client_name}-${var.environment}"
}

# ── GitHub OIDC Provider ──────────────────────────────────────────────────────

# Fetch the GitHub OIDC TLS thumbprint dynamically
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint
  ]

  tags = {
    Name = "${local.name_prefix}-github-oidc"
  }
}

# ── CICD Role (assumed by GitHub Actions) ────────────────────────────────────

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scope trust to the client infra repo plus any additional tooling repos
    # Single platform repo — all workflows (bootstrap, validate, app-deploy) live here
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_platform_repo}:*"]
    }
  }
}

resource "aws_iam_role" "cicd" {
  name                 = "${local.name_prefix}-cicd-role"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume.json
  max_session_duration = 3600

  tags = {
    Name = "${local.name_prefix}-cicd-role"
  }
}

# Give the CICD role broad enough permissions to bootstrap infrastructure.
# Tighten this policy post-MVP once you know exactly what TF touches.
resource "aws_iam_role_policy_attachment" "cicd_admin" {
  role       = aws_iam_role.cicd.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ── Admin Role ────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }

    # Require MFA for human roles
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role" "admin" {
  name               = "${local.name_prefix}-admin-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = {
    Name = "${local.name_prefix}-admin-role"
  }
}

resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = aws_iam_role.admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ── Developer Role ────────────────────────────────────────────────────────────

resource "aws_iam_role" "developer" {
  name               = "${local.name_prefix}-developer-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = {
    Name = "${local.name_prefix}-developer-role"
  }
}

resource "aws_iam_policy" "developer" {
  name        = "${local.name_prefix}-developer-policy"
  description = "Developer access — EKS, ECR, S3, CloudWatch, SSM read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSRead"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRReadWrite"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:${var.aws_account_id}:parameter/${var.client_name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "developer_policy" {
  role       = aws_iam_role.developer.name
  policy_arn = aws_iam_policy.developer.arn
}

# ── Readonly Role ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "readonly" {
  name               = "${local.name_prefix}-readonly-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = {
    Name = "${local.name_prefix}-readonly-role"
  }
}

resource "aws_iam_role_policy_attachment" "readonly_policy" {
  role       = aws_iam_role.readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ── IAM Groups (users are added to groups, groups assume roles) ───────────────

resource "aws_iam_group" "admins" {
  name = "${local.name_prefix}-admins"
}

resource "aws_iam_group" "developers" {
  name = "${local.name_prefix}-developers"
}

resource "aws_iam_group" "readonly" {
  name = "${local.name_prefix}-readonly"
}

# Group policies that allow members to assume the corresponding role

resource "aws_iam_group_policy" "admins_assume" {
  name  = "assume-admin-role"
  group = aws_iam_group.admins.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.admin.arn
    }]
  })
}

resource "aws_iam_group_policy" "developers_assume" {
  name  = "assume-developer-role"
  group = aws_iam_group.developers.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.developer.arn
    }]
  })
}

resource "aws_iam_group_policy" "readonly_assume" {
  name  = "assume-readonly-role"
  group = aws_iam_group.readonly.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.readonly.arn
    }]
  })
}
