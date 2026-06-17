# {{CLIENT_NAME}}

> Auto-generated from [wingu-tech/SWH-Platform-Template](https://github.com/wingu-tech/SWH-Platform-Template)
> by the EKSclientPortal bootstrap pipeline.

This single repository contains everything for the **{{CLIENT_NAME}}** environment:
- **`.iac/`** — Terraform infrastructure (VPC, EKS, IAM, ArgoCD, Grafana, monitoring, security)
- **`application/`** — Application source code deployed via ArgoCD GitOps
- **`templates/`** — Starter templates for creating new applications

---

## Developer Prerequisites

Install the following tools before working with this repository.

### AWS CLI v2

Required to authenticate to AWS and get cluster credentials.

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

Verify: `aws --version`

Configure AWS SSO for the account/permission set you use for this environment.

```bash
aws configure sso
```

You will be prompted for:

```
SSO session name (recommended): swh-platform
SSO start URL:                  https://<your-org>.awsapps.com/start
SSO region:                     us-east-1
SSO registration scopes:        sso:account:access
```

A browser window opens — log in and grant access. Then select the account and permission set
(choose the one with AdministratorAccess). Back in the terminal:

```
CLI default client Region:  us-east-1
CLI default output format:  json
CLI profile name:           swh-platform-admin
```

> Use a descriptive profile name like `swh-platform-admin`.

Log in before each session (SSO tokens expire, typically every 8 hours):

```bash
aws sso login --profile swh-platform-admin
```

Set the profile for your shell session so AWS CLI and helpers use it automatically:

```bash
export AWS_PROFILE=swh-platform-admin
```

Verify:

```bash
aws sts get-caller-identity
```

---

### kubectl

Required to connect to the EKS cluster, view pods/logs, and troubleshoot.

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Verify: `kubectl version --client`

Connect to the cluster (run once, or after credentials expire):

```bash
aws eks update-kubeconfig \
  --name {{CLIENT_NAME}}-eks-dev \
  --region us-east-1
```

---

### git

```bash
# macOS — ships with Xcode Command Line Tools
xcode-select --install

# Linux
sudo apt-get install git       # Debian/Ubuntu
sudo yum install git           # RHEL/Amazon Linux
```

---

### Docker or Podman

Required to build and test application images locally before pushing.

```bash
# macOS — install Docker Desktop or Podman Desktop
# Docker: https://www.docker.com/products/docker-desktop/
# Podman: https://podman-desktop.io/

# Linux
sudo apt-get install docker.io    # Debian/Ubuntu (Docker)
# or:
sudo apt-get install podman       # Debian/Ubuntu (Podman)
```

Verify: `docker --version` or `podman --version`

---

### Node.js >= 18 (frontend development)

Required only if you are working on React frontend code locally.

```bash
# macOS
brew install node

# Linux / any OS (recommended — use nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20 && nvm use 20
```

Verify: `node --version`

---

### Python 3.9+ (backend development)

Required only if you are working on Flask backend code locally.

```bash
# macOS
brew install python@3.12

# Linux
sudo apt-get install python3 python3-pip    # Debian/Ubuntu
sudo yum install python3 python3-pip        # RHEL/Amazon Linux
```

Install backend dependencies for local development:

```bash
cd application/<your-app>/backend
pip3 install -r requirements.txt
```

Verify: `python3 --version`

---

### GitHub CLI (optional but recommended)

Useful for triggering workflows, viewing run logs, and managing PRs from the terminal.

```bash
# macOS
brew install gh

# Linux
sudo apt-get install gh    # after adding the GitHub CLI apt repo
# See: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
```

Authenticate: `gh auth login`

---

## Repository Layout

```
.iac/                         ← Terraform infrastructure
  main.tf
  variables.tf
  modules/
    vpc/  iam/  eks/  monitoring/  security/  kubernetes/

application/                  ← Application workloads (ArgoCD watches this folder)
  splash-page/                ← Platform home page — always deployed, do not remove
    Dockerfile
    backend/                  ← Flask API: serves the React SPA and /api/apps discovery
    frontend/                 ← React SPA: dynamic landing page with app tiles
    k8s/
      deployment.yaml
      service.yaml
      ingress.yaml            ← group.order: 100 (catch-all at /)
      pdb.yaml
  your-app/                   ← Your apps go here — copy from templates/ to get started

templates/                    ← Starter templates (not deployed — copy into application/)
  sample-app1/                ← Hello World Flask + React starter
  README.md                   ← Instructions for creating a new app

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
and managed as a dedicated ArgoCD Application.

**What it does:** the splash page dynamically discovers all deployed services and applications
by reading Kubernetes Ingress resources in the `application` namespace at runtime. Every app
you deploy under `application/` automatically appears as a navigation card on the home page —
no manual configuration needed.

**Do not remove or rename this folder.**

---

## Deploying a New Application

Copy a starter template from `templates/` into `application/`:

```bash
# 1. Copy the template
cp -r templates/sample-app1 application/my-app

# 2. Rename all "sample-app1" references to "my-app" inside the new folder

# 3. In k8s/ingress.yaml — set your path and a unique group.order (30–99):
#      path: /my-app
#      group.order: "30"

# 4. Push to main
git add application/my-app
git commit -m "feat: add my-app"
git push
```

ArgoCD picks it up automatically and a tile appears on the platform home page. See `docs/ADDING_AN_APP.md` for a full walkthrough.

### Reserved ALB group.order values

| Order | Service     |
|-------|-------------|
| 10    | ArgoCD      |
| 20    | Grafana     |
| 100   | Splash Page |

Use any value between **30–99** for your app.

---

## Accessing Platform Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Splash Page | `http://<alb-dns>/` | — |
| ArgoCD | `http://<alb-dns>/argocd` | user: `admin`, password from SSM (see below) |
| Grafana | `http://<alb-dns>/grafana` | user: `admin`, password from SSM (see below) |

Get the ALB DNS name:

```bash
kubectl get ingress -n application
```

Get service passwords from SSM:

```bash
# ArgoCD
kubectl get secret argocd-initial-admin-secret -n tooling \
  -o jsonpath="{.data.password}" | base64 -d

# Grafana
aws ssm get-parameter \
  --name "/{{CLIENT_NAME}}/grafana/admin_password" \
  --with-decryption \
  --query Parameter.Value \
  --output text
```

---

## GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_CICD_ROLE_ARN` | IAM role ARN for GitHub Actions (set by bootstrap pipeline) |
| `AWS_REGION` | AWS region (default: `us-east-1`) |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state |
| `TF_STATE_LOCK_TABLE` | DynamoDB table for state locking |
| `GITHUB_PAT` | GitHub PAT for ArgoCD to pull from this repo |
