#!/usr/bin/env bash
# Final project - application tests, frontend build, Docker images, docker compose stack.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
B="$HOME/venv-s21/bin/python $HOME/devops-homework/session-20-monitoring-observability-gitops/scripts/browser_shot.py"
mkdir -p screenshots/browser

# frontend is built in ~/build (node_modules must not land on OneDrive / in the repo)
rm -rf ~/build/s21-frontend && mkdir -p ~/build && cp -r application/frontend ~/build/s21-frontend
if [ ! -f application/frontend/package-lock.json ]; then
  (cd ~/build/s21-frontend && npm install --no-audit --no-fund >/dev/null 2>&1 && cp package-lock.json "$P/application/frontend/")
fi

snap 01-unit-tests --dir "$P" <<'EOF'
cd application/backend
~/build/s21-venv/bin/pip install -q -r requirements-dev.txt && ~/build/s21-venv/bin/python --version
~/build/s21-venv/bin/ruff check . && echo "ruff: lint OK"
~/build/s21-venv/bin/python -m pytest -v -p no:cacheprovider --cov=app --cov-report=term-missing 2>&1 | grep -vE '^\s*$'
EOF

snap 02-frontend-build --dir "$P" <<'EOF'
cd ~/build/s21-frontend && cp ~/devops-homework/session-21-final-devops-project/final-devops-project/application/frontend/package-lock.json . && node --version && npm --version
npm ci --no-audit --no-fund 2>&1 | tail -n 3
npm run build 2>&1 | tail -n 8
EOF

snap 03-docker-build --dir "$P" --max-lines 80 <<'EOF'
docker build -f docker/backend.Dockerfile -t taskboard-backend:1.0.0 -t ghcr.io/v4xsh/taskboard-backend:1.0.0 . 2>&1 | grep -E '^#[0-9]+ \[|DONE|naming|ERROR' | grep -vE 'CACHED' | tail -n 14
docker build -f docker/frontend.Dockerfile -t taskboard-frontend:1.0.0 -t ghcr.io/v4xsh/taskboard-frontend:1.0.0 . 2>&1 | grep -E '^#[0-9]+ \[|DONE|naming|ERROR' | grep -vE 'CACHED' | tail -n 14
docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E '^taskboard-'
docker inspect taskboard-backend:1.0.0 taskboard-frontend:1.0.0 --format '{{index .Config.Labels "org.opencontainers.image.title"}}  User={{.Config.User}}  ExposedPorts={{json .Config.ExposedPorts}}'
docker run --rm --entrypoint id taskboard-backend:1.0.0
docker run --rm --entrypoint id taskboard-frontend:1.0.0
docker history taskboard-backend:1.0.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -n 8 | cut -c1-120
EOF

snap 04-docker-compose --dir "$P" <<'EOF'
docker compose -f docker/docker-compose.yml up -d --wait 2>&1 | tail -n 6
docker compose -f docker/docker-compose.yml ps -a --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
docker compose -f docker/docker-compose.yml logs migrate | tail -n 3
curl -s localhost:8021/health; echo; curl -s localhost:8021/ready; echo
curl -s -X POST localhost:3021/api/tasks -H 'Content-Type: application/json' -d '{"title":"Write final README","priority":"HIGH","assignee":"Vansh"}'; echo
curl -s -X POST localhost:3021/api/tasks -H 'Content-Type: application/json' -d '{"title":"Run Trivy scan","priority":"MEDIUM","status":"IN_PROGRESS","assignee":"Vansh"}'; echo
curl -s localhost:3021/api/tasks/stats; echo
curl -s -o /dev/null -w 'frontend GET / -> HTTP %{http_code}, %{size_download} bytes\n' localhost:3021/
EOF

$B "http://localhost:3021/" screenshots/browser/taskboard-ui-docker-compose.png --wait-ms 3000 --height 950
docker compose -f docker/docker-compose.yml down -v 2>&1 | tail -n 2
