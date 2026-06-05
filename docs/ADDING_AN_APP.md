# Adding a New Application

Every folder under `application/` (except `splash-page/`) is an independent app.
ArgoCD discovers and deploys it automatically — no config changes needed anywhere else.
Once deployed, the app tile appears on the platform home page at `/`.

---

## Quick Start

Copy the starter template from `templates/` into `application/`:

```bash
cp -r templates/sample-app1 application/your-app-name
```

Then rename all occurrences of `sample-app1` to `your-app-name` inside the new folder,
update the ingress path, and push to main.

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
      pdb.yaml            ← optional but recommended — keeps 1 pod alive during node drains
```

> **Reserved folder:** do not create an app named `splash-page` — it is the platform home
> page and is managed separately.

---

## Step-by-step

### 1. Copy the template

```bash
cp -r templates/sample-app1 application/your-app-name
```

### 2. Rename references

Replace every occurrence of `sample-app1` with `your-app-name` in:
- `k8s/deployment.yaml` — metadata.name, labels, selector, container name
- `k8s/service.yaml` — metadata.name, selector
- `k8s/ingress.yaml` — metadata.name, backend service name
- `k8s/pdb.yaml` — metadata.name, selector
- `frontend/package.json` — the `"name"` field

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
and a card appears on the platform home page.

---

## Backend route prefix

Your Flask app must serve routes under the same path prefix as the ingress. The starter
template already has this wired up. Example for a custom app:

```python
@app.route("/your-app-name")
@app.route("/your-app-name/")
def index():
    return send_from_directory(app.static_folder, "index.html")
```
