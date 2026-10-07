#!/usr/bin/env bash
# Final project - DevSecOps: SAST, SCA, IaC misconfig, secret scan, image scan, security gate (real local runs).
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
export PATH="$HOME/venv-s21/bin:$PATH"
export NODE_OPTIONS=--dns-result-order=ipv4first   # npm registry fetches stalled over IPv6 in this WSL network
chmod +x security/security-gate.sh

snap 05-sast-bandit --dir "$P" <<'EOF'
bandit --version | head -n 1
bandit -c security/bandit.yaml -r application/backend/app -f json -o security/reports/bandit.json -q; jq -r '.metrics._totals | "files=\(.loc) LOC, high=\(."SEVERITY.HIGH") medium=\(."SEVERITY.MEDIUM") low=\(."SEVERITY.LOW")"' security/reports/bandit.json
bandit -c security/bandit.yaml -r application/backend/app -ll -ii; echo "bandit exit code (gate: medium+/medium+): $?"
EOF

snap 06-sca-dependencies --dir "$P" <<'EOF'
pip-audit --version
pip-audit -r application/backend/requirements.txt --strict --desc; echo "pip-audit exit code: $?"
cd application/frontend && npm audit --audit-level=high --package-lock-only; echo "npm audit exit code: $?"; cd "$OLDPWD"
trivy --version | head -n 1
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --quiet application/ ; echo "trivy fs exit code: $?"
EOF

snap 07-iac-trivy-config --dir "$P" --max-lines 90 <<'EOF'
trivy config --severity HIGH,CRITICAL --ignorefile security/.trivyignore --exit-code 1 --quiet . ; echo "trivy config exit code: $?"
EOF

snap 08-secret-scan-gitleaks --dir "$P" <<'EOF'
gitleaks version
gitleaks dir . --config security/gitleaks.toml --redact --no-banner --exit-code 1; echo "gitleaks exit code (project): $?"
mkdir -p /tmp/leak-demo && printf 'GITHUB_TOKEN=ghp_%s\n' "$(head -c 200 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 36)" > /tmp/leak-demo/settings.env
gitleaks dir /tmp/leak-demo --redact --no-banner --exit-code 1; echo "gitleaks exit code (planted fake token, must be 1): $?"
rm -rf /tmp/leak-demo
EOF

snap 09-trivy-image-scan --dir "$P" --max-lines 90 <<'EOF'
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --quiet ghcr.io/v4xsh/taskboard-backend:1.0.0; echo "backend image exit code: $?"
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --quiet ghcr.io/v4xsh/taskboard-frontend:1.0.0; echo "frontend image exit code: $?"
trivy image --severity HIGH,CRITICAL --quiet --format json -o security/reports/trivy-backend.json ghcr.io/v4xsh/taskboard-backend:1.0.0
jq -r '[.Results[].Vulnerabilities[]?] | group_by(.Severity) | map("\(.[0].Severity): \(length) (fixable: \(map(select(.FixedVersion != null and .FixedVersion != "")) | length))") | .[]' security/reports/trivy-backend.json
EOF

snap 10-security-gate --dir "$P" <<'EOF'
security/security-gate.sh ghcr.io/v4xsh/taskboard-backend:1.0.0 ghcr.io/v4xsh/taskboard-frontend:1.0.0; echo "gate exit code: $?"
EOF
