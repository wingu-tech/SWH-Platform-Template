# ── Stage 1: Build React ──────────────────────────────────────────────────────
FROM node:20-alpine AS frontend-build
WORKDIR /app
COPY frontend/package.json ./
RUN npm install --silent
COPY frontend/ ./
# APP_PATH sets the base URL so CRA asset paths match the ALB route prefix
ARG APP_PATH
RUN PUBLIC_URL=${APP_PATH} npm run build

# ── Stage 2: Python backend serving React static files ────────────────────────
FROM python:3.12-slim
WORKDIR /app

COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./
COPY --from=frontend-build /app/build ./static

ARG APP_PATH
ENV APP_PATH=${APP_PATH}
ENV FLASK_APP=app.py

EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
