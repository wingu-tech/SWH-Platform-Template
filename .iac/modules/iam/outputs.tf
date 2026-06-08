output "cicd_role_arn" {
  description = "ARN of the GitHub Actions CICD role."
  value       = aws_iam_role.cicd.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
