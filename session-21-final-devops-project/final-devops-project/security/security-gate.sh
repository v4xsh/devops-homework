#!/usr/bin/env bash
# Local security gate - runs the same checks as the CI pipeline and fails if any of them fails.
#   usage: security/security-gate.sh [backend-image] [frontend-image]     (run from final-devops-project/)
# Tools: bandit, pip-audit (in $VENV or PATH), npm, trivy, gitleaks. Reports are written to security/reports/.
set -u
BACKEND_IMAGE=${1:-ghcr.io/v4xsh/taskboard-backend:1.0.0}
FRONTEND_IMAGE=${2:-ghcr.io/v4xsh/taskboard-frontend:1.0.0}
VENV=${VENV:-$HOME/venv-s21}
PATH="$VENV/bin:$PATH"
R=security/reports
mkdir -p "$R"
declare -A RESULT

run() {  # run <name> <command...>
  local name=$1; shift
  if "$@" > "$R/$name.log" 2>&1; then RESULT[$name]=PASS; else RESULT[$name]=FAIL; fi
  printf '%-22s %s\n' "$name" "${RESULT[$name]}"
}

run sast-bandit      bandit -c security/bandit.yaml -r application/backend/app -ll -ii
run sca-pip-audit    pip-audit -r application/backend/requirements.txt --strict
run sca-npm-audit    bash -c "cd application/frontend && timeout 180 npm audit --audit-level=high --package-lock-only"
run sca-trivy-fs     trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 application/
run iac-trivy-config trivy config --severity HIGH,CRITICAL --ignorefile security/.trivyignore --exit-code 1 .
run secrets-gitleaks gitleaks dir . --config security/gitleaks.toml --redact --no-banner --exit-code 1
run image-backend    trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$BACKEND_IMAGE"
run image-frontend   trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$FRONTEND_IMAGE"

echo "----------------------------------------"
for k in "${!RESULT[@]}"; do [ "${RESULT[$k]}" = FAIL ] && { echo "SECURITY GATE: FAILED ($k)"; exit 1; }; done
echo "SECURITY GATE: PASSED - all ${#RESULT[@]} checks green, images may be pushed"
