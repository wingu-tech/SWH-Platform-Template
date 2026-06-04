output "guardduty_detector_id" {
  value = var.create_account_security ? aws_guardduty_detector.main[0].id : ""
}

output "cloudtrail_name" {
  value = aws_cloudtrail.main.name
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.cloudtrail.bucket
}

output "config_recorder_name" {
  value = var.create_account_security ? aws_config_configuration_recorder.main[0].name : ""
}
