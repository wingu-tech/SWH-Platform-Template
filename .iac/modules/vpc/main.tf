# ---------------------------------------------------------------------------
# VPC Module
# Uses the community terraform-aws-modules/vpc module under the hood.
# EKS-specific subnet tags are applied so the cluster can auto-discover subnets.
# ---------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.client_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + length(var.availability_zones))]

  enable_nat_gateway   = true
  single_nat_gateway   = true # set false for HA in production
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS subnet auto-discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Name = "${var.client_name}-${var.environment}-vpc"
  }
}
