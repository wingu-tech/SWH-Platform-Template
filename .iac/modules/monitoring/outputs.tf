output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "alarm_sns_arn" {
  description = "SNS topic ARN used for alarms (created or passed in)."
  value       = var.alarm_sns_arn != "" ? var.alarm_sns_arn : aws_sns_topic.alarms[0].arn
}

output "eks_log_group_name" {
  description = "CloudWatch log group for EKS control plane (owned by EKS module)."
  value       = "/aws/eks/${var.cluster_name}/cluster"
}
