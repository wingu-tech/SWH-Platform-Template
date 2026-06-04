output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}

output "cloudtrail_name" {
  value = aws_cloudtrail.main.name
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.cloudtrail.bucket
}

output "config_recorder_name" {
  value = aws_config_configuration_recorder.main.name
}
