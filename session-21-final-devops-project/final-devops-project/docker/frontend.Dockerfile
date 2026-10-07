# syntax=docker/dockerfile:1
# TaskBoard frontend - Node build stage + unprivileged Nginx runtime. Build context: final-devops-project/
#   docker build -f docker/frontend.Dockerfile -t taskboard-frontend:1.0.0 .

# ---------- stage 1: build the React/Vite bundle ----------
FROM node:22-alpine AS build
WORKDIR /app
COPY application/frontend/package.json application/frontend/package-lock.json ./
ENV NPM_CONFIG_FETCH_TIMEOUT=30000 NPM_CONFIG_FETCH_RETRIES=5
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund
COPY application/frontend/ ./
RUN npm run build

# ---------- stage 2: static files served by nginx as UID 101 on port 8080 ----------
FROM nginxinc/nginx-unprivileged:1.29-alpine AS runtime
LABEL org.opencontainers.image.title="taskboard-frontend" \
      org.opencontainers.image.source="https://github.com/v4xsh/devops-homework" \
      org.opencontainers.image.authors="Vansh Dobhal (10099)"
USER root
RUN apk upgrade --no-cache
USER 101
# the official entrypoint renders /etc/nginx/templates/*.template with envsubst at start-up
ENV BACKEND_URL=http://backend:8000
COPY docker/nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
