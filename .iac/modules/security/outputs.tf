output "guardduty_detector_id" {
  value = var.create_account_security ? aws_guardduty_detector.main[0].id : ""
}

output "cloudtrail_name" {
  value = aws_cloudtrail.main.name
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.cloudtrail.bucket
}

output "alb_certificate_arn" {
  value = local.alb_certificate_arn
}
