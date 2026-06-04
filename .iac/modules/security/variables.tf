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
