output "argocd_namespace" {
  description = "Namespace ArgoCD is installed in."
  value       = kubernetes_namespace.tooling.metadata[0].name
}

output "app_namespace" {
  description = "Namespace application workloads are deployed to."
  value       = kubernetes_namespace.application.metadata[0].name
}

output "sourcecode_url" {
  description = "GitHub URL ArgoCD is watching."
  value       = local.sourcecode_url
}

output "ingress_group_name" {
  description = "ALB IngressGroup name shared across all apps."
  value       = var.ingress_group_name
}
