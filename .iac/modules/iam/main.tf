# ---------------------------------------------------------------------------
# IAM Module
# Creates:
#   - GitHub Actions OIDC provider
#   - CICD role (assumed by GitHub Actions via OIDC — scoped to platform repo)
#
# User/group management is handled by the platform team above this layer.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.client_name}-${var.environment}"
}

# ── GitHub OIDC Provider ──────────────────────────────────────────────────────

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
  permissions_boundary = var.permissions_boundary != "" ? var.permissions_boundary : null

  tags = {
    Name = "${local.name_prefix}-cicd-role"
  }
}

resource "aws_iam_role_policy_attachment" "cicd_admin" {
  role       = aws_iam_role.cicd.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
