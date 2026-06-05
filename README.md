# {{CLIENT_NAME}}-platform

> Auto-generated from [wingu-tech/SWH-Platform-Template](https://github.com/wingu-tech/SWH-Platform-Template)
> by the EKSclientPortal bootstrap pipeline.

This single repository contains everything for the **{{CLIENT_NAME}}** environment:
- **`.iac/`** — Terraform infrastructure (VPC, EKS, IAM, ArgoCD, Grafana, monitoring, security)
- **`application/`** — Application source code deployed via ArgoCD GitOps

---

## Repository Layout

```
.iac/                         ← Terraform infrastructure
  main.tf
  variables.tf
  modules/
    vpc/  iam/  eks/  monitoring/  security/  kubernetes/

application/                  ← Application workloads
  splash-page/                ← Platform home page (always deployed, do not remove)
    Dockerfile
    backend/                  ← Flask API — serves the React SPA and /api/apps discovery
    frontend/                 ← React SPA — dynamic landing page
    k8s/
      deployment.yaml
      service.yaml
      ingress.yaml            ← group.order: 100 (catch-all at /)
      pdb.yaml

  templates/                  ← Reference templates — copy these to create a new app
    sample-app1/              ← Hello World starter template
    README.md                 ← Instructions for creating a new app

docs/
  ADDING_AN_APP.md            ← Step-by-step guide for deploying a new application

.github/workflows/
  bootstrap.yml               ← Provisions infrastructure on merge to main (watches .iac/**)
  validate.yml                ← Plan + Checkov scan on PRs (watches .iac/**)
  app-deploy.yml              ← Build + push Docker images on merge to main (watches application/**)
```

---

## The Splash Page

`application/splash-page/` is the **platform home page** served at `/`. It is always deployed
and is managed as a dedicated ArgoCD Application (not auto-discovered).

**What it does:** the splash page dynamically discovers all deployed services and applications
by reading Kubernetes Ingress resources in the `application` namespace at runtime. Every app
you deploy under `application/` automatically appears as a navigation card on the home page —
no manual configuration needed.

**Do not remove or rename this folder.** It is required for platform navigation.

---

## Deploying a New Application

To create your own app, copy a template from `application/templates/` into `application/`:

```bash
# 1. Copy the template
cp -r application/templates/sample-app1 application/my-app

# 2. Rename all references inside the new folder
#    Replace "sample-app1" with "my-app" in all files

# 3. Update k8s/ingress.yaml:
#      - Set path: /my-app
#      - Pick a unique group.order between 30-99

# 4. Push to main — ArgoCD syncs automatically and the tile appears on the splash page
git add application/my-app
git commit -m "feat: add my-app"
git push
```

See `docs/ADDING_AN_APP.md` for a full walkthrough.

### Reserved ALB group.order values

| Order | Service     |
|-------|-------------|
| 10    | ArgoCD      |
| 20    | Grafana     |
| 100   | Splash Page |

Use any value between **30–99** for your app.

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
| `AWS_REGION` | AWS region (default: `us-east-1`) |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state |
| `TF_STATE_LOCK_TABLE` | DynamoDB table for state locking |
| `GITHUB_PAT` | GitHub PAT for ArgoCD to pull from this repo |
