variable "client_name" { type = string }
variable "environment" { type = string }
variable "aws_account_id" { type = string }
variable "aws_region" { type = string }

variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform state — added to CloudTrail data events."
  type        = string
}
