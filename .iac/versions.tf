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

# Kubernetes + Helm providers wired to EKS — only active if create_eks = true
provider "kubernetes" {
  host                   = var.create_eks ? module.eks[0].cluster_endpoint : ""
  cluster_ca_certificate = var.create_eks ? base64decode(module.eks[0].cluster_ca_certificate) : ""

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", var.create_eks ? module.eks[0].cluster_name : "",
      "--region", var.aws_region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = var.create_eks ? module.eks[0].cluster_endpoint : ""
    cluster_ca_certificate = var.create_eks ? base64decode(module.eks[0].cluster_ca_certificate) : ""

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", var.create_eks ? module.eks[0].cluster_name : "",
        "--region", var.aws_region
      ]
    }
  }
}
