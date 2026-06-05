import os
import requests
from flask import Flask, jsonify, send_from_directory

app = Flask(__name__, static_folder="static", static_url_path="")

@app.route("/")
def index():
    return send_from_directory(app.static_folder, "index.html")

@app.errorhandler(404)
def not_found(e):
    return send_from_directory(app.static_folder, "index.html")

@app.route("/api/health")
def health():
    return jsonify({"status": "ok"})

@app.route("/api/apps")
def apps():
    """
    Reads Ingress resources from the application namespace via the
    in-cluster Kubernetes API. Returns a list of deployed apps for
    the splash page to render as navigation cards.
    """
    try:
        token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        ca_path = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        ns_path = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"

        with open(token_path) as f:
            token = f.read().strip()
        with open(ns_path) as f:
            namespace = f.read().strip()

        url = (
            f"https://kubernetes.default.svc"
            f"/apis/networking.k8s.io/v1/namespaces/{namespace}/ingresses"
        )
        resp = requests.get(
            url,
            headers={"Authorization": f"Bearer {token}"},
            verify=ca_path,
            timeout=5,
        )
        resp.raise_for_status()

        discovered = []
        for ing in resp.json().get("items", []):
            name = ing["metadata"]["name"]
            for rule in ing.get("spec", {}).get("rules", [{}]):
                for path_item in rule.get("http", {}).get("paths", []):
                    path = path_item.get("path", "/")
                    if path and path != "/":
                        discovered.append({"name": name, "path": path})

        return jsonify(discovered)

    except Exception:
        return jsonify([])


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
