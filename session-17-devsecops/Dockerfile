# Session 17 - DevSecOps demo image
# BASE_IMAGE is a build argument so the pipeline demo can show the security gate
# failing on an old, vulnerable base image and passing on the current one.
ARG BASE_IMAGE=python:3.12-slim
FROM ${BASE_IMAGE}

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

ARG GIT_SHA=dev
ENV GIT_SHA=${GIT_SHA}

# non-root user with a fixed UID (matches runAsUser in k8s/deployment.yaml)
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
USER 10001

EXPOSE 8000
# --worker-tmp-dir /tmp: the root filesystem is read-only in Kubernetes, /tmp is an emptyDir
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--worker-tmp-dir", "/tmp", "app.main:app"]
