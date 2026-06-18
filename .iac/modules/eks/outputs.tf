output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "node_group_role_arn" {
  value = aws_iam_role.eks_compute.arn
}

output "cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}
