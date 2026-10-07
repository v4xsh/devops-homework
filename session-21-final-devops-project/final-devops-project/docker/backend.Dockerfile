# syntax=docker/dockerfile:1
# TaskBoard backend - multi-stage build. Build context: final-devops-project/
#   docker build -f docker/backend.Dockerfile -t taskboard-backend:1.0.0 .

# ---------- stage 1: build a virtualenv with all dependencies ----------
FROM python:3.12-slim AS builder
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY application/backend/requirements.txt .
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip \
 && /opt/venv/bin/pip install -r requirements.txt \
 && /opt/venv/bin/pip uninstall -y pip

# ---------- stage 2: small runtime image, no compilers, non-root ----------
FROM python:3.12-slim AS runtime
LABEL org.opencontainers.image.title="taskboard-backend" \
      org.opencontainers.image.source="https://github.com/v4xsh/devops-homework" \
      org.opencontainers.image.authors="Vansh Dobhal (10099)"
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PATH="/opt/venv/bin:$PATH"
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/* \
 && pip uninstall -y pip setuptools wheel || true \
 && groupadd --gid 10001 app && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY --chown=10001:10001 application/backend/alembic.ini ./
COPY --chown=10001:10001 application/backend/alembic ./alembic
COPY --chown=10001:10001 application/backend/app ./app
USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"
# migrations are run separately (compose "migrate" service / Kubernetes init container): alembic upgrade head
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--no-server-header"]
