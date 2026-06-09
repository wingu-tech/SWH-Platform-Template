terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Client      = var.client_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repo        = "wingu-tech/${var.client_name}-infra"
    }
  }
}

# Kubernetes + Helm providers wired to EKS.
# When create_eks = false the exec block is skipped entirely and a placeholder
# static token is used — this prevents any aws eks get-token API calls which
# cause hangs on restricted corporate networks during -target=module.iam.
provider "kubernetes" {
  host                   = var.create_eks ? module.eks[0].cluster_endpoint : "https://localhost"
  cluster_ca_certificate = var.create_eks ? base64decode(module.eks[0].cluster_ca_certificate) : ""
  token                  = var.create_eks ? null : "placeholder"

  dynamic "exec" {
    for_each = var.create_eks ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks[0].cluster_name,
        "--region", var.aws_region
      ]
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = var.create_eks ? module.eks[0].cluster_endpoint : "https://localhost"
    cluster_ca_certificate = var.create_eks ? base64decode(module.eks[0].cluster_ca_certificate) : ""
    token                  = var.create_eks ? null : "placeholder"

    dynamic "exec" {
      for_each = var.create_eks ? [1] : []
      content {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args = [
          "eks", "get-token",
          "--cluster-name", module.eks[0].cluster_name,
          "--region", var.aws_region
        ]
      }
    }
  }
}
