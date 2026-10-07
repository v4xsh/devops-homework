#!/usr/bin/env bash
# Run the GitHub Actions pipeline locally with nektos/act (CI + DevSecOps jobs + image build/scan + gate).
# act needs a git checkout, so the project is copied into a throw-away workspace (/tmp/act-ws) with the same
# layout as the real repo and committed there - never in the submission repo.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
ROOT=~/devops-homework
W=/tmp/act-ws
rm -rf "$W" && mkdir -p "$W/session-21-final-devops-project" "$W/.github/workflows"
rsync -a --exclude outputs --exclude screenshots --exclude 'troubleshooting/outputs' --exclude 'troubleshooting/screenshots' \
      --exclude node_modules --exclude dist --exclude __pycache__ --exclude '.pytest_cache' --exclude 'security/reports' \
      "$P" "$W/session-21-final-devops-project/"
cp "$ROOT/.github/workflows/session21-final-pipeline.yml" "$W/.github/workflows/"
cd "$W" && git init -q -b main && git config user.name "Vansh Dobhal" && git config user.email vansh@taskboard.local \
  && git add . && git commit -q -m "TaskBoard final project snapshot for local act run"
cat > /tmp/act-event.json <<'JSON'
{"act": true, "pull_request": {"head": {"ref": "feature/final-project"}, "base": {"ref": "main"}}}
JSON
export NODE_OPTIONS=--dns-result-order=ipv4first

snap 32-act-list-jobs --dir "$P" <<'EOF'
cd /tmp/act-ws && act --version
act pull_request -W .github/workflows/session21-final-pipeline.yml -l 2>/dev/null
EOF

cd "$W"
# act uses the host network by default; IPv6 on this WSL host has no working route and npm stalled for 20+ minutes on
# AAAA records (first attempt). Job containers therefore run on the docker bridge network and prefer IPv4.
act pull_request -W .github/workflows/session21-final-pipeline.yml -e /tmp/act-event.json \
  -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/amd64 \
  --network bridge --env NODE_OPTIONS=--dns-result-order=ipv4first > /tmp/act-run.log 2>&1
echo "act exit code: $?" >> /tmp/act-run.log
cp /tmp/act-run.log "$P/security/reports/act-run.log"

snap 33-act-pipeline-run --dir "$P" --max-lines 95 <<'EOF'
grep -E '^\[.*\] (🏁|✅|❌|⭐ Run (Main|Post)? ?(Pytest|Lint|Bandit|pip-audit|npm audit|Trivy|gitleaks|Build images|All quality|npm ci))' /tmp/act-run.log | sed -E 's/^\[session21-final-pipeline\/([^]]*)\]/[\1]/' | grep -vE 'Post ' | head -n 70
grep -E 'Job (succeeded|failed)|act exit code' /tmp/act-run.log | sed -E 's/^\[session21-final-pipeline\/([^]]*)\]/[\1]/'
EOF

snap 34-act-job-details --dir "$P" --max-lines 95 <<'EOF'
grep -E '[0-9]+ passed|TOTAL|Required test coverage' /tmp/act-run.log | sed -E 's/^\[session21-final-pipeline\/([^]]*)\]/[\1]/' | head -n 4
grep -E 'No issues identified|No known vulnerabilities found|found 0 vulnerabilities|no leaks found' /tmp/act-run.log | sed -E 's/^\[session21-final-pipeline\/([^]]*)\]/[\1]/'
grep -E 'Total: [0-9]+ \(HIGH|security gate|test=|sca=' /tmp/act-run.log | sed -E 's/^\[session21-final-pipeline\/([^]]*)\]/[\1]/' | head -n 12
EOF
