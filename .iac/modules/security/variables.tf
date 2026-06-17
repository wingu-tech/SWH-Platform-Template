variable "client_name" { type = string }
variable "environment" { type = string }
variable "aws_account_id" { type = string }
variable "aws_region" { type = string }

variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform state — added to CloudTrail data events."
  type        = string
}

variable "create_account_security" {
  description = "Create account-level security resources (GuardDuty, AWS Config). Set false when multiple clients share one AWS account (testing only). Defaults true for real single-client accounts."
  type        = bool
  default     = true
}

variable "existing_alb_certificate_arn" {
  description = "Existing ACM certificate ARN for ALB HTTPS. If empty and create_self_signed_alb_certificate=true, a self-signed cert is generated/imported."
  type        = string
  default     = ""
}

variable "create_self_signed_alb_certificate" {
  description = "Generate and import a self-signed ACM certificate when no existing ALB cert ARN is provided."
  type        = bool
  default     = true
}

variable "self_signed_alb_cert_common_name" {
  description = "Common Name/SAN used for the generated self-signed ACM certificate."
  type        = string
  default     = "localhost"
}
