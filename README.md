# {{CLIENT_NAME}}

> Auto-generated from `SWH-Platform-Template`
> by the EKSclientPortal bootstrap pipeline.

This single repository contains everything for the **{{CLIENT_NAME}}** environment:
- **`.iac/`** — Terraform infrastructure (VPC, EKS, IAM, ArgoCD, Grafana, monitoring, security)
- **`application/`** — Application source code deployed via ArgoCD GitOps
- **`templates/`** — Starter templates for creating new applications

---

## Machine Prerequisites

Install all of the following on the machine you'll run the scripts from.

### 1. AWS CLI v2

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

Verify: `aws --version` → should show `aws-cli/2.x`

The IAM user or role you configure needs **AdministratorAccess** (or at minimum: IAM, S3,
DynamoDB, SSM, EKS, EC2, VPC full access) — the local bootstrap creates the OIDC provider
and IAM roles that GitHub Actions will use for all subsequent applies.

Use AWS SSO (recommended for org accounts):

If your organization uses AWS IAM Identity Center (SSO), use this instead of static keys.

**1. Configure the SSO profile (one-time setup)**

```bash
aws configure sso
```

You will be prompted for:

```
SSO session name (recommended): swh-platform
SSO start URL:                  use the URL shown in AWS Access Keys
SSO region:                     us-east-1
SSO registration scopes:        sso:account:access
```

To find your exact SSO Start URL for these accounts:

1. Open `https://tentsandbox.awsapps.com/start`
2. Select the **Access keys** icon
3. Copy the **SSO Start URL** shown there and use it in `aws configure sso`

A browser window opens — log in and grant access. Then select the account and permission set
(choose the one with AdministratorAccess). Back in the terminal:

```
CLI default client Region:  us-east-1
CLI default output format:  json
CLI profile name:           swh-platform-admin
```

> Use a descriptive profile name like `swh-platform-admin`. You will reference it in every session.

**2. Log in before each session**

SSO tokens expire (typically every 8 hours). Run this at the start of each working session:

```bash
aws sso login --profile swh-platform-admin
```

**3. Set the profile for the current session**

Export it so all AWS CLI commands and the Python scripts pick it up automatically:

```bash
export AWS_PROFILE=swh-platform-admin
```

> Add this to your shell profile (`~/.zshrc` or `~/.bashrc`) if you use this account daily.

Verify: `aws sts get-caller-identity`

### 2. OpenTofu >= 1.6

```bash
# macOS
brew install opentofu

# Linux (or any OS via tfenv)
curl --proto '=https' --tlsv1.2 -fsSL https://get.tofuenv.app | bash
source ~/.bashrc
tenv tofu install latest && tenv tofu use latest
```

Verify: `tofu version` → should show `OpenTofu v1.8.x` or higher

---

### 3. Python 3.9+

```bash
# macOS
brew install python@3.12

# Linux
sudo apt-get install python3 python3-pip   # Debian/Ubuntu
sudo yum install python3 python3-pip       # RHEL/Amazon Linux
```

Install required Python packages (these are pip-only — they cannot be installed via brew):

```bash
pip3 install PyGithub boto3 requests
```

> **Gotcha — `externally-managed-environment` error on newer macOS:** Python 3.12+ from Homebrew
> blocks system-wide pip installs by default. Fix it with:
> ```bash
> pip3 install PyGithub boto3 requests --break-system-packages
> ```

Verify: `python3 --version` → `Python 3.9+`

---

### 4. GitHub CLI

```bash
# macOS
brew install gh

# Linux
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y))
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh -y
```

Authenticate:

```bash
gh auth login
# Select: GitHub.com → HTTPS → Login with a web browser (or paste a token)
```

Verify: `gh auth status`

---

### 5. kubectl

Used to verify cluster access after provisioning and for any manual troubleshooting.

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Verify: `kubectl version --client`

---

### 6. git

```bash
# macOS — ships with Xcode Command Line Tools
xcode-select --install

# Linux
sudo apt-get install git   # Debian/Ubuntu
sudo yum install git       # RHEL/Amazon Linux
```

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
