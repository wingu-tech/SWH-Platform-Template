# ---------------------------------------------------------------------------
# Root Outputs
# ---------------------------------------------------------------------------

output "client_name" {
  description = "Client slug used in all resource names."
  value       = var.client_name
}

output "environment" {
  description = "Deployment environment label."
  value       = var.environment
}

output "vpc_id" {
  description = "VPC ID in use (created or pre-existing)."
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs in use."
  value       = local.private_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = var.create_eks ? module.eks[0].cluster_name : null
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = var.create_eks ? module.eks[0].cluster_endpoint : null
  sensitive   = true
}

output "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64)."
  value       = var.create_eks ? module.eks[0].cluster_ca_certificate : null
  sensitive   = true
}

output "cicd_role_arn" {
  description = "IAM role ARN used by GitHub Actions for deployments."
  value       = var.create_iam ? module.iam[0].cicd_role_arn : null
}
