# ---------------------------------------------------------------------------
# EKS Module
# Builds the cluster, managed node group, core add-ons, and aws-auth ConfigMap.
# Uses terraform-aws-modules/eks for the heavy lifting.
# ---------------------------------------------------------------------------

locals {
  role_tags = {
    Client      = var.client_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  admin_access_entries = {
    for idx, principal_arn in var.admin_principal_arns : "admin_${idx}" => {
      kubernetes_groups = []
      principal_arn     = principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name                 = "${var.cluster_name}-cluster-role"
  permissions_boundary = var.permissions_boundary != "" ? var.permissions_boundary : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.role_tags, {
    Name = "${var.cluster_name}-cluster-role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_compute" {
  name                 = "${var.cluster_name}-compute-role"
  permissions_boundary = var.permissions_boundary != "" ? var.permissions_boundary : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.role_tags, {
    Name = "${var.cluster_name}-compute-role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_compute_worker" {
  role       = aws_iam_role.eks_compute.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_compute_ecr_pull" {
  role       = aws_iam_role.eks_compute.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_compute_cni" {
  role       = aws_iam_role.eks_compute.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_compute_cloudwatch" {
  role       = aws_iam_role.eks_compute.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_compute_xray" {
  role       = aws_iam_role.eks_compute.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = var.vpc_id
  subnet_ids                     = var.private_subnet_ids
  cluster_endpoint_public_access = true # set false and use VPN/bastion for prod
  create_iam_role                = false
  iam_role_arn                   = aws_iam_role.eks_cluster.arn

  # EKS Managed Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # Managed node groups:
  # - default: untainted, receives cluster/system workloads by default
  # - tooling: tainted for platform components (ArgoCD, Grafana, etc.)
  # - app: tainted for application workloads that opt-in with tolerations
  eks_managed_node_groups = {
    default = {
      name           = "${var.cluster_name}-ng-default"
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      create_iam_role = false
      iam_role_arn    = aws_iam_role.eks_compute.arn

      # ami_type must be set when use_latest_ami_release_version = true
      ami_type                       = "AL2_x86_64"
      use_latest_ami_release_version = true

      labels = {
        role = "default"
      }
    }

    tooling = {
      name           = "${var.cluster_name}-ng-tooling"
      instance_types = var.node_instance_types
      min_size       = var.tooling_node_min_size
      max_size       = var.tooling_node_max_size
      desired_size   = var.tooling_node_desired_size

      create_iam_role = false
      iam_role_arn    = aws_iam_role.eks_compute.arn

      ami_type                       = "AL2_x86_64"
      use_latest_ami_release_version = true

      labels = {
        role     = "tooling"
        workload = "tooling"
      }

      taints = {
        workload = {
          key    = "workload"
          value  = "tooling"
          effect = "NO_SCHEDULE"
        }
      }
    }

    app = {
      name           = "${var.cluster_name}-ng-app"
      instance_types = var.node_instance_types
      min_size       = var.app_node_min_size
      max_size       = var.app_node_max_size
      desired_size   = var.app_node_desired_size

      create_iam_role = false
      iam_role_arn    = aws_iam_role.eks_compute.arn

      ami_type                       = "AL2_x86_64"
      use_latest_ami_release_version = true

      labels = {
        role     = "app"
        workload = "app"
      }

      taints = {
        workload = {
          key    = "workload"
          value  = "app"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  # Cluster creator gets admin automatically — don't add a duplicate entry
  enable_cluster_creator_admin_permissions = false

  access_entries = merge({
    cicd = {
      kubernetes_groups = []
      principal_arn     = var.cicd_role_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }, local.admin_access_entries)

  tags = {
    Name = var.cluster_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_compute_worker,
    aws_iam_role_policy_attachment.eks_compute_ecr_pull,
    aws_iam_role_policy_attachment.eks_compute_cni,
    aws_iam_role_policy_attachment.eks_compute_cloudwatch,
    aws_iam_role_policy_attachment.eks_compute_xray,
  ]
}

# ── IRSA for EBS CSI Driver ───────────────────────────────────────────────────

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
