# ---------------------------------------------------------------------------
# Root Variables
# All {{TOKEN}} placeholders are injected by bootstrap_client.py at repo
# creation time. Do not hardcode values here — edit terraform.tfvars instead.
# ---------------------------------------------------------------------------

# ── Core Identity ────────────────────────────────────────────────────────────

variable "client_name" {
  description = "Short slug used in all resource names (e.g. acmecorp). Lowercase, no spaces."
  type        = string
}

variable "aws_account_id" {
  description = "Target AWS account ID for this client."
  type        = string
}

variable "aws_region" {
  description = "Primary AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (dev / staging / prod)."
  type        = string
  default     = "dev"
}

variable "client_domain" {
  description = "Approved domain for this client (e.g. acmecorp.example.com). Used in ACM/Route53 if applicable."
  type        = string
  default     = ""
}

# ── Module Toggles ───────────────────────────────────────────────────────────

variable "create_vpc" {
  description = "Set false if the client account already has a VPC to use."
  type        = bool
  default     = true
}

variable "create_iam" {
  description = "Create baseline IAM roles, groups, and OIDC provider."
  type        = bool
  default     = true
}

variable "create_eks" {
  description = "Provision an EKS cluster and managed node groups."
  type        = bool
  default     = true
}

variable "create_monitoring" {
  description = "Deploy CloudWatch dashboards and Container Insights."
  type        = bool
  default     = true
}

variable "create_security" {
  description = "Enable security resources (CloudTrail, SSM baseline)."
  type        = bool
  default     = true
}

# ── Existing Network (used when create_vpc = false) ──────────────────────────

variable "existing_vpc_id" {
  description = "ID of an existing VPC. Only required when create_vpc = false."
  type        = string
  default     = ""
}

variable "existing_private_subnet_ids" {
  description = "List of existing private subnet IDs. Only required when create_vpc = false."
  type        = list(string)
  default     = []
}

variable "existing_public_subnet_ids" {
  description = "List of existing public subnet IDs. Only required when create_vpc = false."
  type        = list(string)
  default     = []
}

# ── VPC Config (used when create_vpc = true) ─────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the new VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread subnets across."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ── EKS Config ────────────────────────────────────────────────────────────────

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.32"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the default managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}

variable "eks_tooling_node_desired_size" {
  description = "Desired number of tooling nodes (tainted workload=tooling)."
  type        = number
  default     = 1
}

variable "eks_tooling_node_min_size" {
  description = "Minimum number of tooling nodes."
  type        = number
  default     = 1
}

variable "eks_tooling_node_max_size" {
  description = "Maximum number of tooling nodes."
  type        = number
  default     = 2
}

variable "eks_app_node_desired_size" {
  description = "Desired number of app nodes (tainted workload=app)."
  type        = number
  default     = 1
}

variable "eks_app_node_min_size" {
  description = "Minimum number of app nodes."
  type        = number
  default     = 1
}

variable "eks_app_node_max_size" {
  description = "Maximum number of app nodes."
  type        = number
  default     = 3
}

# ── IAM / GitHub OIDC ─────────────────────────────────────────────────────────

variable "github_org" {
  description = "GitHub organization name (e.g. wingu-tech)."
  type        = string
}

variable "github_platform_repo" {
  description = "GitHub repo name for this platform repo (e.g. acmecorp-platform). Contains both .iac/ and application/."
  type        = string
}

# ── Kubernetes / ArgoCD ───────────────────────────────────────────────────────

variable "create_kubernetes" {
  description = "Create namespaces and install ArgoCD with ApplicationSet."
  type        = bool
  default     = true
}

variable "github_pat_ssm_path" {
  description = "SSM Parameter Store path for the GitHub PAT used by ArgoCD."
  type        = string
  default     = ""
}

variable "grafana_github_oauth_ssm_path" {
  description = "SSM path prefix for Grafana GitHub OAuth credentials. Empty disables OAuth."
  type        = string
  default     = ""
}

# ── State Backend ─────────────────────────────────────────────────────────────

variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform remote state."
  type        = string
}

variable "tf_state_lock_table" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
  default     = "terraform-state-lock"
}

variable "create_account_security" {
  description = "Create account-level resources (GuardDuty, AWS Config recorder). Set false when multiple clients share one AWS account — e.g. testing. Default true."
  type        = bool
  default     = true
}

variable "permissions_boundary" {
  description = "ARN of the IAM permissions boundary policy to attach to all created roles. Required in accounts that enforce boundary policies (e.g. arn:aws:iam::<account>:policy/Deny_Default_VPC). Leave empty if not required."
  type        = string
  default     = ""
}
