output "cicd_role_arn" {
  description = "ARN of the GitHub Actions CICD role."
  value       = aws_iam_role.cicd.arn
}

output "admin_role_arn" {
  description = "ARN of the admin role."
  value       = aws_iam_role.admin.arn
}

output "developer_role_arn" {
  description = "ARN of the developer role."
  value       = aws_iam_role.developer.arn
}

output "readonly_role_arn" {
  description = "ARN of the readonly role."
  value       = aws_iam_role.readonly.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "admin_group_name" {
  value = aws_iam_group.admins.name
}

output "developer_group_name" {
  value = aws_iam_group.developers.name
}

output "readonly_group_name" {
  value = aws_iam_group.readonly.name
}
