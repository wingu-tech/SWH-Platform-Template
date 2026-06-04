# Adding a New Application

Every folder under `application/` is an independent app. The pipeline discovers
it automatically — no config changes needed anywhere else.

---

## Folder Structure

```
application/
  your-app-name/          ← folder name becomes the app name and ECR repo name
    Dockerfile            ← required — how to build the image
    k8s/
      deployment.yaml     ← required — runs your container
      service.yaml        ← required — exposes it inside the cluster
      ingress.yaml        ← required — puts it on the shared ALB
      pdb.yaml            ← recommended — keeps one replica up during node drain
    src/                  ← your application code (any structure you want)
```

> **Naming rules:** Use lowercase letters, numbers, and hyphens only.
> No underscores — Kubernetes rejects them in resource names.
> ✅ `my-app` ✅ `payments-api` ❌ `my_app`

---

## Step 1 — Copy sample-app1

The fastest start is copying the sample app and renaming everything:

```bash
cp -r application/sample-app1 application/your-app-name
```

Then update every place `sample-app1` appears in the `k8s/` files to `your-app-name`.

---

## Step 2 — k8s/deployment.yaml

Replace `sample-app1` with your app name. The image field is managed by the pipeline —
leave it as the nginx placeholder for now, the workflow will update it on first push.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-app-name            # ← change this
  namespace: application
  labels:
    app: your-app-name           # ← change this
spec:
  replicas: 1
  selector:
    matchLabels:
      app: your-app-name         # ← change this
  template:
    metadata:
      labels:
        app: your-app-name       # ← change this
    spec:
      containers:
        - name: your-app-name    # ← change this
          image: public.ecr.aws/nginx/nginx:alpine   # pipeline replaces this automatically
          ports:
            - containerPort: 8080    # ← match your app's port
          readinessProbe:
            httpGet:
              path: /health          # ← match your health endpoint
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
```

---

## Step 3 — k8s/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: your-app-name       # ← change this
  namespace: application
spec:
  selector:
    app: your-app-name      # ← change this — must match deployment labels
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080      # ← match your container port
  type: ClusterIP
```

---

## Step 4 — k8s/ingress.yaml

This is what puts your app on the shared ALB. Every new app gets its own path — the
path should match your app folder name.

**How routing works:**
- `/` is reserved for the platform splash page (`sample-app1`) — don't use it
- ArgoCD lives at `/argocd` (priority 10) and Grafana at `/grafana` (priority 20)
- Your app goes at `/<your-app-name>` with a `group.order` between 20 and 100

**group.order** — controls which rules are checked first. Lower number = checked first.
New apps with specific paths should use `30`, `40`, `50`, etc.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: your-app-name           # ← change this
  namespace: application
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/group.name: shared          # never change this
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/healthcheck-path: /health   # ← match your health endpoint
    alb.ingress.kubernetes.io/group.order: "30"           # ← pick a unique number (30-99)
spec:
  rules:
    - http:
        paths:
          - path: /your-app-name    # ← your path, or / for catch-all
            pathType: Prefix
            backend:
              service:
                name: your-app-name # ← change this
                port:
                  number: 80
```

### group.order quick reference

| Value | Used by | Notes |
|-------|---------|-------|
| `10` | ArgoCD (`/argocd`) | Reserved |
| `20` | Grafana (`/grafana`) | Reserved |
| `30–99` | Your apps | Pick any unused number |
| `100` | sample-app1 (`/`) | Splash page catch-all — reserved, don't use |

> **Base path configuration:** Since your app is served at `/<your-app-name>`,
> your code needs to know about this prefix.
> - **React:** set `"homepage": "/<your-app-name>"` in `package.json`
> - **Flask:** set `APPLICATION_ROOT = '/<your-app-name>'` or use a Blueprint with `url_prefix`
> - **Node/Express:** mount routes with `app.use('/<your-app-name>', router)`
>
> Without this, asset paths (`/static/js/main.js`) won't resolve correctly.

---

## Step 5 — k8s/pdb.yaml

Keeps at least one replica running during node maintenance or scaling events.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: your-app-name       # ← change this
  namespace: application
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: your-app-name    # ← change this — must match deployment labels
```

---

## Step 6 — Dockerfile

Build your image. The multi-stage sample builds React then serves via Flask/gunicorn.
Adapt to your stack — the only requirement is that the final image listens on the
port you set in `deployment.yaml`.

```dockerfile
FROM your-base-image AS build
WORKDIR /app
COPY . .
RUN your-build-command

FROM your-runtime-image
WORKDIR /app
COPY --from=build /app/dist ./dist
EXPOSE 8080
CMD ["your-start-command"]
```

---

## Step 7 — Push to main

Once your files are in place, push to `main`:

```bash
git add application/your-app-name/
git commit -m "feat: add your-app-name"
git push origin main
```

**What happens automatically:**
1. `app-deploy.yml` detects `application/your-app-name/` changed
2. Creates an ECR repo named `your-app-name` (if it doesn't exist)
3. Builds the Docker image from `application/your-app-name/Dockerfile`
4. Tags it with a timestamp (`MMddyyyyHHmm`) and pushes to ECR
5. Updates `k8s/deployment.yaml` with the real image tag and commits back
6. ArgoCD detects the commit and deploys your app to the `application` namespace
7. The shared ALB picks up the new Ingress rule within ~30 seconds

**Check deployment status in ArgoCD:**
```
http://<alb-dns>/argocd
```

---

## Checklist

- [ ] Folder name uses hyphens not underscores
- [ ] `deployment.yaml` — name, labels, container port, health path updated
- [ ] `service.yaml` — name and selector updated, targetPort matches container port
- [ ] `ingress.yaml` — name, path, group.order (unique 30–99), healthcheck-path updated
- [ ] `pdb.yaml` — name and selector updated
- [ ] `Dockerfile` — builds and exposes correct port
- [ ] Pushed to `main` — pipeline triggers automatically
