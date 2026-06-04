variable "client_name" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "aws_region" { type = string }

variable "alarm_sns_arn" {
  description = "ARN of an existing SNS topic for alarm notifications. Leave empty to create a new one."
  type        = string
  default     = ""
}
