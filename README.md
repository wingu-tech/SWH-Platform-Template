# {{CLIENT_NAME}}-platform

> Auto-generated from [wingu-tech/template-platform](https://github.com/wingu-tech/template-platform)
> by the EKSclientPortal bootstrap pipeline.

This single repository contains everything for the **{{CLIENT_NAME}}** environment:
- **`.iac/`** — Terraform infrastructure (VPC, EKS, IAM, ArgoCD, Grafana, monitoring, security)
- **`application/`** — Application source code deployed via ArgoCD GitOps

---

## Repository Layout

```
.iac/                   ← Terraform infrastructure
  main.tf
  variables.tf
  modules/
    vpc/  iam/  eks/  monitoring/  security/  kubernetes/

application/            ← Application workloads
  sample-app1/
    Dockerfile
    k8s/
      deployment.yaml
      service.yaml
      ingress.yaml
      pdb.yaml

docs/
  ADDING_AN_APP.md      ← Guide for deploying a new application

.github/workflows/
  bootstrap.yml         ← Provisions infrastructure on merge to main (watches .iac/**)
  validate.yml          ← Plan + Checkov scan on PRs (watches .iac/**)
  app-deploy.yml        ← Build + push Docker images on merge to main (watches application/**)
```

---

## First-time Setup (one-time, run locally)

The GitHub Actions OIDC role is created by Terraform, so the first apply
must run locally to bootstrap it:

```bash
cd .iac
terraform init
terraform apply -target=module.iam -auto-approve
```

Then clear the state locks (see output from prereqs.sh) and merge the bootstrap PR.

---

## GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_CICD_ROLE_ARN` | IAM role ARN for GitHub Actions (from first local apply) |
| `AWS_REGION` | AWS region, e.g. `us-east-1` |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state |
| `TF_STATE_LOCK_TABLE` | DynamoDB table name for state locking |
| `AWS_ACCOUNT_ID` | AWS account ID (used by app-deploy.yml for ECR) |

---

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `bootstrap.yml` | Push to main touching `.iac/**` | Full `terraform apply` |
| `validate.yml` | PR touching `.iac/**` | fmt, validate, plan, Checkov scan |
| `app-deploy.yml` | Push to main touching `application/**` | Build + push ECR images, ArgoCD deploys |

---

## Adding a New Application

See `docs/ADDING_AN_APP.md` for the full guide with copy-paste templates.

Quick summary: add `application/your-app-name/` with a `Dockerfile` and `k8s/` manifests,
push to `main`, and the pipeline handles the rest automatically.

---

## Service URLs (after bootstrap)

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | `http://<alb>/argocd` | `admin` / see `kubectl get secret argocd-initial-admin-secret` |
| Grafana | `http://<alb>/grafana` | `admin` / SSM `/{{CLIENT_NAME}}/grafana/admin_password` |
| Platform Home | `http://<alb>/` | — |
