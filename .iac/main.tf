# ---------------------------------------------------------------------------
# Root Module — wires all child modules together
# Each module is individually toggleable via create_<module> variables
# ---------------------------------------------------------------------------

locals {
  # Resolved network values — works whether VPC is created or pre-existing
  vpc_id             = var.create_vpc ? module.vpc[0].vpc_id : var.existing_vpc_id
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnet_ids : var.existing_private_subnet_ids
  public_subnet_ids  = var.create_vpc ? module.vpc[0].public_subnet_ids : var.existing_public_subnet_ids

  cluster_name = "${var.client_name}-eks-${var.environment}"
}

# ── VPC ───────────────────────────────────────────────────────────────────────

module "vpc" {
  count  = var.create_vpc ? 1 : 0
  source = "./modules/vpc"

  client_name        = var.client_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  cluster_name       = local.cluster_name
}

# ── IAM ───────────────────────────────────────────────────────────────────────

module "iam" {
  count  = var.create_iam ? 1 : 0
  source = "./modules/iam"

  client_name       = var.client_name
  environment       = var.environment
  aws_account_id    = var.aws_account_id
  github_org        = var.github_org
  github_infra_repo = var.github_infra_repo
  cluster_name      = local.cluster_name

  # Always trust the sourcecode repo so app-deploy.yml can assume the CICD role
  additional_oidc_repos = concat(
    var.additional_oidc_repos,
    ["${var.github_org}/${var.github_sourcecode_repo}"]
  )
}

# ── EKS ───────────────────────────────────────────────────────────────────────

module "eks" {
  count  = var.create_eks ? 1 : 0
  source = "./modules/eks"

  client_name         = var.client_name
  environment         = var.environment
  cluster_name        = local.cluster_name
  cluster_version     = var.eks_cluster_version
  vpc_id              = local.vpc_id
  private_subnet_ids  = local.private_subnet_ids
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size

  # Pass the cicd role ARN so it's added to aws-auth from the start
  cicd_role_arn  = var.create_iam ? module.iam[0].cicd_role_arn : ""
  admin_role_arn = var.create_iam ? module.iam[0].admin_role_arn : ""

  depends_on = [module.vpc, module.iam]
}

# ── Monitoring ────────────────────────────────────────────────────────────────

module "monitoring" {
  count  = var.create_monitoring ? 1 : 0
  source = "./modules/monitoring"

  client_name  = var.client_name
  environment  = var.environment
  cluster_name = local.cluster_name
  aws_region   = var.aws_region

  # Must wait for kubernetes module so LBC webhook is ready before
  # the observability addon tries to create services that trigger it.
  depends_on = [module.eks, module.kubernetes]
}

# ── Security ──────────────────────────────────────────────────────────────────

module "security" {
  count  = var.create_security ? 1 : 0
  source = "./modules/security"

  client_name     = var.client_name
  environment     = var.environment
  aws_account_id  = var.aws_account_id
  aws_region      = var.aws_region
  tf_state_bucket = var.tf_state_bucket
}

# ── Kubernetes (namespaces + ArgoCD + ApplicationSet) ─────────────────────────

module "kubernetes" {
  count  = var.create_kubernetes ? 1 : 0
  source = "./modules/kubernetes"

  client_name          = var.client_name
  environment          = var.environment
  cluster_name         = local.cluster_name
  github_org           = var.github_org
  github_platform_repo = var.github_platform_repo
  github_pat_ssm_path  = var.github_pat_ssm_path
  oidc_provider_arn    = var.create_eks ? module.eks[0].oidc_provider_arn : ""
  aws_account_id       = var.aws_account_id
  aws_region           = var.aws_region

  grafana_admin_password_ssm_path = "/${var.client_name}/grafana/admin_password"
  grafana_github_oauth_ssm_path   = var.grafana_github_oauth_ssm_path

  depends_on = [module.eks]
}
