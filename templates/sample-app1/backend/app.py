import os
from flask import Flask, jsonify, send_from_directory

# APP_PATH is injected at build time (e.g. "/app1").
# Flask serves static assets under this prefix so ALB routes them correctly.
APP_PATH = os.environ.get("APP_PATH", "")
app = Flask(__name__, static_folder="static", static_url_path=APP_PATH)

@app.route(f"{APP_PATH}")
@app.route(f"{APP_PATH}/")
def index():
    return send_from_directory(app.static_folder, "index.html")

@app.errorhandler(404)
def not_found(e):
    return send_from_directory(app.static_folder, "index.html")

@app.route("/api/health")
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
