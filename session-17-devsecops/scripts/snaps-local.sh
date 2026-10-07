#!/usr/bin/env bash
# Run every DevSecOps stage directly (outside the pipeline) and capture it with `snap`.
# Runs inside the throw-away git checkout made by act-stage.sh (exact copy of this folder + 1 local
# commit), because gitleaks needs git history and semgrep stalls when it walks up into the huge
# git repository that contains my Windows home directory.
set -euo pipefail
export PATH="$HOME/venvs/s1617/bin:$PATH"
S=~/devops-homework/session-17-devsecops
bash "$S/scripts/act-stage.sh" session-17-devsecops session17-devsecops.yml
export STAGE=~/act-stage/session-17-devsecops/devops-homework
export W=$STAGE/session-17-devsecops
cd "$W"

snap 01-build-and-unit-tests --dir "$S" --cols 150 <<'EOF'
cd $W && git log --oneline -1
pip install -q -r requirements-dev.txt && pip list 2>/dev/null | grep -iE '^(flask|gunicorn|werkzeug|pytest) '
python -m compileall -q app && echo "compileall OK"
pytest -v -p no:cacheprovider --cov=app --cov-report=term-missing --cov-fail-under=90 2>&1 | tail -n 22
EOF

snap 02-sast-bandit --dir "$S" --cols 150 <<'EOF'
cat .bandit
bandit -r app --ini .bandit 2>/dev/null | sed -n '/Test results/,$p'
bandit -r sast-demo -q -f custom --msg-template '{severity:6} {confidence:6} {test_id} {relpath}:{line}  {msg}' 2>/dev/null | cut -c1-140
EOF

snap 03-sast-semgrep --dir "$S" --cols 150 <<'EOF'
grep -E '^  - id:' .semgrep.yml
semgrep scan --metrics=off --disable-version-check --config .semgrep.yml app 2>&1 | grep -E 'Findings|Rules run|Targets scanned|Ran '
semgrep scan --metrics=off --disable-version-check --config .semgrep.yml --json sast-demo 2>/dev/null | jq -r '.results[] | "\(.extra.severity)\t\(.check_id)\t\(.path):\(.start.line)"'
EOF

mkdir -p /tmp/s17-vuln-deps && printf 'Flask==3.1.2\ngunicorn==20.1.0\n' > /tmp/s17-vuln-deps/requirements.txt
snap 04-sca-pip-audit-trivy-fs --dir "$S" --cols 160 --max-lines 90 <<'EOF'
cat requirements.txt
pip-audit -r requirements.txt --desc off
trivy fs --config trivy.yaml --quiet --format table . 2>&1 | tail -n 8
cat /tmp/s17-vuln-deps/requirements.txt
pip-audit -r /tmp/s17-vuln-deps/requirements.txt --desc off; echo "pip-audit exit code: $?"
trivy fs --config trivy.yaml --quiet --format table /tmp/s17-vuln-deps 2>&1 | grep -vE '^\s*$' | cut -c1-158 | head -n 30
EOF

# --- secret scanning: plant a FAKE credential on a feature branch (random values, never real) ---
cd "$STAGE"
git checkout -q -b feature/add-test-fixture
mkdir -p session-17-devsecops/tests/fixtures
rnd() { python3 -c "import secrets,sys; print(''.join(secrets.choice(sys.argv[1]) for _ in range(int(sys.argv[2]))))" "$1" "$2"; }
FAKE_AKID="AKIA$(rnd ABCDEFGHIJKLMNOPQRSTUVWXYZ234567 16)"
FAKE_SECRET="$(rnd ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 40)"
FAKE_TOKEN="s17tok_$(rnd ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 32)"
cat > session-17-devsecops/tests/fixtures/legacy_settings.py <<PY
# fixture copied from an old settings file - it accidentally still contains credentials
# (values are randomly generated fakes for the gitleaks demo)
AWS_ACCESS_KEY_ID = "${FAKE_AKID}"
AWS_SECRET_ACCESS_KEY = "${FAKE_SECRET}"
S17_API_TOKEN = "${FAKE_TOKEN}"
PY
git add -A && git -c user.name="Vansh Dobhal" -c user.email="vanshdobhal11@gmail.com" \
  commit -q -m "test: add legacy settings fixture"
unset FAKE_AKID FAKE_SECRET FAKE_TOKEN
cd "$W"

snap 05-secret-scan-gitleaks-catches-leak --dir "$S" --cols 160 <<'EOF'
git branch --show-current && git log --oneline -2 && git show --stat --format= HEAD
gitleaks git --config .gitleaks.toml --redact --no-banner --verbose --log-opts="-- session-17-devsecops" .. 2>&1 | grep -vE '^\s*$'; echo "gitleaks exit code: ${PIPESTATUS[0]}"
EOF

git checkout -q main
snap 06-secret-scan-gitleaks-clean --dir "$S" --cols 160 <<'EOF'
git branch --show-current && git log --oneline -1
gitleaks git --config .gitleaks.toml --redact --no-banner --log-opts="-- session-17-devsecops" .. 2>&1; echo "gitleaks git exit code: $?"
gitleaks dir --config .gitleaks.toml --redact --no-banner . 2>&1; echo "gitleaks dir exit code: $?"
EOF

snap 07-docker-build-and-trivy-image --dir "$S" --cols 160 --max-lines 80 <<'EOF'
docker build -q --build-arg GIT_SHA=local -t s17-devsecops-api:local . && docker image inspect s17-devsecops-api:local --format 'base=python:3.12-slim user={{.Config.User}} size={{.Size}}'
trivy image --config trivy.yaml --quiet --format table s17-devsecops-api:local 2>&1 | grep -E 'Total|─|│' | cut -c1-150 | head -n 12
docker build -q --build-arg BASE_IMAGE=public.ecr.aws/docker/library/python:3.9.7-slim-buster -t s17-devsecops-api:old-base . >/dev/null && echo "built s17-devsecops-api:old-base (python:3.9.7-slim-buster, 2021)"
trivy image --config trivy.yaml --quiet --format json s17-devsecops-api:old-base 2>/dev/null | jq -r '.Results[] | "\(.Target): \([.Vulnerabilities[]?.Severity] | group_by(.) | map("\(.[0])=\(length)") | join(" "))"'
EOF
docker rmi -f s17-devsecops-api:old-base >/dev/null
