# Adding a New Application

Every folder under `application/` (except `splash-page/` and `templates/`) is an
independent app. ArgoCD discovers and deploys it automatically — no config changes
needed anywhere else. Once deployed, the app tile appears on the platform home page.

---

## Quick Start

The fastest way to create a new app is to copy the starter template:

```bash
cp -r application/templates/sample-app1 application/your-app-name
```

Then rename all occurrences of `sample-app1` to `your-app-name` inside the new folder,
update the ingress path, and push.

---

## Folder Structure

```
application/
  your-app-name/          ← folder name becomes the app name and ECR repo name
    Dockerfile            ← required — how to build the image
    k8s/
      deployment.yaml     ← required — runs your container
      service.yaml        ← required — exposes it inside the cluster
      ingress.yaml        ← required — routes ALB traffic to your app
      pdb.yaml            ← optional but recommended — keeps 1 pod running during node drains
```

> **Reserved folders** — do not create apps named `splash-page` or inside `templates/`.
> These are excluded from ArgoCD auto-discovery:
> - `application/splash-page/` — platform home page, always-on
> - `application/templates/` — reference templates, not deployed

---

## Step-by-step

### 1. Copy the template

```bash
cp -r application/templates/sample-app1 application/your-app-name
```

### 2. Rename references

Replace every occurrence of `sample-app1` with `your-app-name` in:
- `k8s/deployment.yaml` (metadata.name, labels, selector, container name)
- `k8s/service.yaml` (metadata.name, selector)
- `k8s/ingress.yaml` (metadata.name, backend service name)
- `k8s/pdb.yaml` (metadata.name, selector)
- `frontend/package.json` ("name" field)

### 3. Set your ingress path

In `k8s/ingress.yaml`, set a unique path and group order:

```yaml
annotations:
  alb.ingress.kubernetes.io/group.order: "30"   # pick an unused value 30–99
spec:
  rules:
    - http:
        paths:
          - path: /your-app-name
            pathType: Prefix
```

**Reserved group.order values:**

| Order | Service     |
|-------|-------------|
| 10    | ArgoCD      |
| 20    | Grafana     |
| 100   | Splash Page |

### 4. Push to main

```bash
git add application/your-app-name
git commit -m "feat: add your-app-name"
git push
```

The `app-deploy.yml` workflow builds the Docker image, pushes it to ECR, and ArgoCD
syncs the manifests. Within a couple of minutes the app is live at `/your-app-name`
and a card appears on the platform home page at `/`.

---

## Backend route prefix

Your Flask app must serve routes under the same path prefix as the ingress. Example:

```python
@app.route("/your-app-name")
@app.route("/your-app-name/")
def index():
    return send_from_directory(app.static_folder, "index.html")
```

The starter template in `application/templates/sample-app1/` already has this wired up.
