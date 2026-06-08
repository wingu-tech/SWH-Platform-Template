variable "client_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_platform_repo" {
  description = "Platform repo name — the single repo containing .iac/ and application/."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used to scope EKS permissions in developer policy."
  type        = string
}

variable "permissions_boundary" {
  description = "ARN of the IAM permissions boundary policy to attach to all created roles. Required in accounts that enforce boundary policies (e.g. arn:aws:iam::<account>:policy/Deny_Default_VPC)."
  type        = string
  default     = ""
}
