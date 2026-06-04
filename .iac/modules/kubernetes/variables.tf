variable "client_name" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }

variable "github_org" {
  type = string
}

variable "github_platform_repo" {
  description = "Platform repo name — contains .iac/ (infrastructure) and application/ (apps)."
  type        = string
}

variable "github_pat_ssm_path" {
  description = "SSM Parameter Store path where the GitHub PAT is stored."
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace to install ArgoCD into."
  type        = string
  default     = "tooling"
}

variable "app_namespace" {
  description = "Namespace where application workloads run."
  type        = string
  default     = "application"
}

variable "argocd_chart_version" {
  description = "Helm chart version for ArgoCD."
  type        = string
  default     = "7.7.22"
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN — used to create the LBC IRSA role."
  type        = string
}

variable "lbc_chart_version" {
  description = "Helm chart version for the AWS Load Balancer Controller."
  type        = string
  default     = "1.8.3"
}

variable "ingress_group_name" {
  description = "ALB IngressGroup name. All apps in this client share one ALB."
  type        = string
  default     = "shared"
}

# ── Grafana ───────────────────────────────────────────────────────────────────

variable "grafana_chart_version" {
  description = "Helm chart version for Grafana."
  type        = string
  default     = "8.4.4"
}

variable "grafana_admin_password_ssm_path" {
  description = "SSM path for the Grafana admin password. Created by prereqs.sh."
  type        = string
}

variable "grafana_github_oauth_ssm_path" {
  description = "SSM path prefix for GitHub OAuth credentials. Empty string disables OAuth."
  type        = string
  default     = ""
}

variable "aws_account_id" {
  description = "AWS account ID — used to scope CloudWatch data source permissions."
  type        = string
}

variable "aws_region" {
  description = "AWS region — used to configure the CloudWatch data source."
  type        = string
}
