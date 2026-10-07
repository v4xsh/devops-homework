#!/usr/bin/env bash
# Final project - fix what the security gate found in 1.0.0, rebuild as 1.0.1, run the gate again.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
export PATH="$HOME/venv-s21/bin:$PATH"
export NODE_OPTIONS=--dns-result-order=ipv4first   # npm registry fetches stalled over IPv6 in this WSL network

# regenerate the npm lock file for the bumped vite / plugin-react (outside OneDrive)
if ! grep -q '"node_modules/vite": {' application/frontend/package-lock.json || ! grep -A1 '"node_modules/vite": {' application/frontend/package-lock.json | grep -q '7.3.7'; then
  rm -rf ~/build/s21-frontend && cp -r application/frontend ~/build/s21-frontend
  (cd ~/build/s21-frontend && rm -f package-lock.json && npm install --no-audit --no-fund >/dev/null 2>&1 && cp package-lock.json "$P/application/frontend/")
fi

snap 11-remediation-1.0.1 --dir "$P" --max-lines 80 <<'EOF'
grep -E "^(fastapi|starlette|prometheus-fastapi-instrumentator)==" application/backend/requirements.txt
grep -E '"(vite|@vitejs/plugin-react)"' application/frontend/package.json
grep -n 'pip uninstall' docker/backend.Dockerfile
~/build/s21-venv/bin/pip install -q -r application/backend/requirements-dev.txt && cd application/backend && ~/build/s21-venv/bin/python -m pytest -q -p no:cacheprovider 2>&1 | tail -n 1; cd "$OLDPWD"
pip-audit -r application/backend/requirements.txt --strict; echo "pip-audit exit code: $?"
cd application/frontend && npm audit --audit-level=high --package-lock-only; echo "npm audit exit code: $?"; cd "$OLDPWD"
docker build -q -f docker/backend.Dockerfile -t taskboard-backend:1.0.1 -t ghcr.io/v4xsh/taskboard-backend:1.0.1 .
docker build -q -f docker/frontend.Dockerfile -t taskboard-frontend:1.0.1 -t ghcr.io/v4xsh/taskboard-frontend:1.0.1 .
docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E '^ghcr.io/v4xsh/taskboard-.*:1.0.1'
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --quiet --format json -o /tmp/trivy-b101.json ghcr.io/v4xsh/taskboard-backend:1.0.1; echo "backend 1.0.1 image exit code: $?"; jq -r "\"fixable HIGH/CRITICAL findings in 1.0.1: \" + ([.Results[].Vulnerabilities[]?] | length | tostring)" /tmp/trivy-b101.json
EOF

snap 12-security-gate-passed --dir "$P" <<'EOF'
security/security-gate.sh ghcr.io/v4xsh/taskboard-backend:1.0.1 ghcr.io/v4xsh/taskboard-frontend:1.0.1; echo "gate exit code: $?"
EOF
