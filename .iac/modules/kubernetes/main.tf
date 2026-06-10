# ---------------------------------------------------------------------------
# Kubernetes Module
# Creates:
#   - tooling namespace  (ArgoCD, infrastructure tooling)
#   - application namespace (client workloads)
#   - ArgoCD installed via Helm in tooling namespace
#   - ArgoCD repo secret wired to the client sourcecode repo (GitHub PAT)
#   - ArgoCD ApplicationSet watching application/* in the sourcecode repo
# ---------------------------------------------------------------------------

locals {
  name_prefix    = "${var.client_name}-${var.environment}"
  sourcecode_url = "https://github.com/${var.github_org}/${var.github_platform_repo}.git"
}

# ── Namespaces ────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "tooling" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_namespace" "application" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ── Platform Config ───────────────────────────────────────────────────────────
# Exposes the client name to pods as an env var so the splash page can
# display it without rebuilding the image per client.

resource "kubernetes_config_map" "platform_config" {
  metadata {
    name      = "platform-config"
    namespace = kubernetes_namespace.application.metadata[0].name
  }
  data = {
    client_name = var.client_name
  }
}

# ── RBAC — allow app pods to read Ingress resources ───────────────────────────
# The splash page (sample-app1) reads Ingress resources to auto-discover
# deployed apps and display them as navigation cards.

resource "kubernetes_role" "ingress_reader" {
  metadata {
    name      = "ingress-reader"
    namespace = kubernetes_namespace.application.metadata[0].name
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "ingress_reader" {
  metadata {
    name      = "ingress-reader"
    namespace = kubernetes_namespace.application.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.ingress_reader.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.application.metadata[0].name
  }
}

# ── GitHub PAT from SSM ───────────────────────────────────────────────────────

data "aws_ssm_parameter" "github_pat" {
  name            = var.github_pat_ssm_path
  with_decryption = true
}

# ── AWS Load Balancer Controller ─────────────────────────────────────────────

module "lbc_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${local.name_prefix}-lbc"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.lbc_chart_version

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lbc_irsa.iam_role_arn
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = kubernetes_namespace.tooling.metadata[0].name
  create_namespace = false
  timeout          = 600

  values = [
    yamlencode({
      global = {
        domain = ""
      }
      server = {
        service = {
          type = "ClusterIP"
        }
        nodeSelector = {
          workload = "tooling"
        }
        tolerations = [{
          key      = "workload"
          operator = "Equal"
          value    = "tooling"
          effect   = "NoSchedule"
        }]
      }
      controller = {
        nodeSelector = {
          workload = "tooling"
        }
        tolerations = [{
          key      = "workload"
          operator = "Equal"
          value    = "tooling"
          effect   = "NoSchedule"
        }]
      }
      repoServer = {
        nodeSelector = {
          workload = "tooling"
        }
        tolerations = [{
          key      = "workload"
          operator = "Equal"
          value    = "tooling"
          effect   = "NoSchedule"
        }]
      }
      applicationSet = {
        nodeSelector = {
          workload = "tooling"
        }
        tolerations = [{
          key      = "workload"
          operator = "Equal"
          value    = "tooling"
          effect   = "NoSchedule"
        }]
      }
      redis = {
        nodeSelector = {
          workload = "tooling"
        }
        tolerations = [{
          key      = "workload"
          operator = "Equal"
          value    = "tooling"
          effect   = "NoSchedule"
        }]
      }
      configs = {
        params = {
          "server.insecure" = true
          "server.rootpath" = "/argocd"
        }
      }
    })
  ]
}

# ── ArgoCD Repo Secret ────────────────────────────────────────────────────────
# Gives ArgoCD credentials to clone the private sourcecode repo

resource "kubernetes_secret" "argocd_repo" {
  metadata {
    name      = "${var.client_name}-sourcecode-repo"
    namespace = kubernetes_namespace.tooling.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = local.sourcecode_url
    username = "git"
    password = data.aws_ssm_parameter.github_pat.value
  }

  depends_on = [helm_release.argocd]
}

# ── ArgoCD ApplicationSet ─────────────────────────────────────────────────────
# Applied via kubectl in bootstrap.yml after ArgoCD is ready.
# kubernetes_manifest requires a live cluster at plan time, so we store the
# manifest as a ConfigMap and apply it in a post-apply workflow step.

resource "kubernetes_config_map" "argocd_appset_manifest" {
  metadata {
    name      = "${local.name_prefix}-appset"
    namespace = kubernetes_namespace.tooling.metadata[0].name
  }

  data = {
    "appset.yaml" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "ApplicationSet"
      metadata = {
        name      = "${local.name_prefix}-apps"
        namespace = kubernetes_namespace.tooling.metadata[0].name
      }
      spec = {
        generators = [{
          git = {
            repoURL  = local.sourcecode_url
            revision = "HEAD"
            directories = [
              { path = "application/*" },
              # splash-page is deployed as a static Application (always-on home page)
              { path = "application/splash-page", exclude = true },
            ]
          }
        }]
        template = {
          metadata = { name = "{{path.basename}}" }
          spec = {
            project = "default"
            source = {
              repoURL        = local.sourcecode_url
              targetRevision = "HEAD"
              path           = "{{path}}/k8s"
            }
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = var.app_namespace
            }
            syncPolicy = {
              automated   = { prune = true, selfHeal = true }
              syncOptions = ["CreateNamespace=true"]
            }
          }
        }
      }
    })
  }

  depends_on = [helm_release.argocd]
}

# ── ArgoCD Application — Splash Page ─────────────────────────────────────────
# The splash page lives in a bracketed folder (excluded from the ApplicationSet)
# so it gets its own explicit Application manifest stored as a ConfigMap.

resource "kubernetes_config_map" "argocd_splashpage_manifest" {
  metadata {
    name      = "${local.name_prefix}-splashpage-app"
    namespace = kubernetes_namespace.tooling.metadata[0].name
  }

  data = {
    "splashpage-app.yaml" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "splash-page"
        namespace = kubernetes_namespace.tooling.metadata[0].name
      }
      spec = {
        project = "default"
        source = {
          repoURL        = local.sourcecode_url
          targetRevision = "HEAD"
          path           = "application/splash-page/k8s"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.app_namespace
        }
        syncPolicy = {
          automated   = { prune = true, selfHeal = true }
          syncOptions = ["CreateNamespace=true"]
        }
      }
    })
  }

  depends_on = [helm_release.argocd]
}

# ── ArgoCD Ingress ────────────────────────────────────────────────────────────
# Exposes ArgoCD via the shared ALB at /argocd — no port-forwarding needed.

resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd"
    namespace = kubernetes_namespace.tooling.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/group.name"       = var.ingress_group_name
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/argocd/healthz"
      "alb.ingress.kubernetes.io/success-codes"    = "200"
      # Low group.order = high priority — specific paths matched before the app catch-all
      "alb.ingress.kubernetes.io/group.order" = "10"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/argocd"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# ── Grafana ───────────────────────────────────────────────────────────────────

data "aws_ssm_parameter" "grafana_admin_password" {
  name            = var.grafana_admin_password_ssm_path
  with_decryption = true
}

# IRSA role giving Grafana pods read access to CloudWatch metrics and logs
module "grafana_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.name_prefix}-grafana"

  role_policy_arns = {
    cloudwatch = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.argocd_namespace}:grafana"]
    }
  }
}

locals {
  grafana_root_url = "%(protocol)s://%(domain)s/grafana"

  # GitHub OAuth is enabled only when the SSM path is provided
  grafana_github_oauth_enabled = var.grafana_github_oauth_ssm_path != ""
}

resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = var.grafana_chart_version
  namespace        = kubernetes_namespace.tooling.metadata[0].name
  create_namespace = false
  timeout          = 300

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.grafana_irsa.iam_role_arn
        }
      }
      nodeSelector = {
        workload = "tooling"
      }
      tolerations = [{
        key      = "workload"
        operator = "Equal"
        value    = "tooling"
        effect   = "NoSchedule"
      }]

      "grafana.ini" = {
        server = {
          domain              = ""
          root_url            = local.grafana_root_url
          serve_from_sub_path = true
        }
        auth = {
          disable_login_form   = false
          disable_signout_menu = false
        }
        "auth.anonymous" = {
          enabled = false
        }
      }

      adminPassword = data.aws_ssm_parameter.grafana_admin_password.value

      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [{
            name      = "CloudWatch"
            type      = "cloudwatch"
            access    = "proxy"
            isDefault = true
            jsonData = {
              authType      = "default"
              defaultRegion = var.aws_region
            }
          }]
        }
      }

      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [{
            name            = "container-insights"
            orgId           = 1
            folder          = "Container Insights"
            type            = "file"
            disableDeletion = false
            options = {
              path = "/var/lib/grafana/dashboards/container-insights"
            }
          }]
        }
      }

      # Pre-load AWS Container Insights dashboards from grafana.com
      dashboards = {
        container-insights = {
          eks-cluster = {
            gnetId     = 17119
            revision   = 1
            datasource = "CloudWatch"
          }
          eks-nodes = {
            gnetId     = 17122
            revision   = 1
            datasource = "CloudWatch"
          }
          eks-pods = {
            gnetId     = 17138
            revision   = 1
            datasource = "CloudWatch"
          }
        }
      }
    })
  ]

  depends_on = [helm_release.lbc]
}

resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.tooling.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/group.name"       = var.ingress_group_name
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
      "alb.ingress.kubernetes.io/success-codes"    = "200"
      "alb.ingress.kubernetes.io/group.order"      = "20"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/grafana"
          path_type = "Prefix"
          backend {
            service {
              name = "grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.grafana]
}
