# Application Templates

Copy a template folder into `application/` to deploy a new app on the platform.

## How to use

1. Copy `application/templates/sample-app1/` to `application/your-app-name/`
2. Rename all references from `sample-app1` to `your-app-name` inside the copied folder
3. In `k8s/ingress.yaml`, set a unique `path:` (e.g. `/your-app-name`) and pick an unused `group.order` between 20-99
4. Push to `main` — ArgoCD picks it up automatically and the tile appears on the splash page

## Reserved group.order values

| Order | Service     |
|-------|-------------|
| 10    | ArgoCD      |
| 20    | Grafana     |
| 100   | Splash Page |

Use any value between 30–99 for your app.
