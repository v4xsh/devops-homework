#!/usr/bin/env bash
# Three real act runs of the DevSecOps workflow (run after snaps-local.sh, which created the
# throw-away checkout and the feature/add-test-fixture branch with a planted FAKE credential):
#   run 1  feature/add-test-fixture  -> secret scan finds the leak, pipeline stops
#   run 2  main + vulnerable commit  -> scanners report, security gate FAILS, nothing pushed/deployed
#   run 3  main + fix (revert)       -> everything passes, image pushed and deployed
set -euo pipefail
export PATH="$HOME/venvs/s1617/bin:$PATH"
export S=~/devops-homework/session-17-devsecops
export STAGE=~/act-stage/session-17-devsecops/devops-homework
cd "$STAGE"
GIT="git -c user.name=Vansh_Dobhal -c user.email=vanshdobhal11@gmail.com"
kubectl delete namespace s17 --ignore-not-found --wait=true

# ---------------------------------------------------------------- run 1: leaked secret
git checkout -q feature/add-test-fixture
rm -rf /tmp/act-artifacts-s17
export LOG1=$S/outputs/act-s17-run1-leak-branch.log
snap 08-act-run1-secret-leak-blocks-pipeline --dir "$S" --cols 170 --max-lines 80 <<'EOF'
cd $STAGE && git branch --show-current && git log --oneline -2
bash $S/scripts/act-run.sh push 2>&1 | sed -r 's/\x1b\[[0-9;]*m//g' > $LOG1; echo "act exit code: ${PIPESTATUS[0]}"
awk '/Run Main Scan git history/{f=1} f&&/\| /{print} /Failure - Main Scan git history/{exit}' $LOG1 | grep -vE '\|\s*$|[○│░╲]' | cut -c1-168
grep -E 'Job (succeeded|failed)|Failure - Main' $LOG1
grep -cE '/(6\. Docker Build|7\. Image Scan|8\. Security Gate|9\. Push Image|10\. Deploy)' $LOG1
EOF

# ---------------------------------------------------------------- run 2: vulnerable dependencies + old base image
git checkout -q main
sed -i 's/^Flask==.*/Flask==3.1.2/; s/^gunicorn==.*/gunicorn==20.1.0/' session-17-devsecops/requirements.txt
sed -i 's#^ARG BASE_IMAGE=.*#ARG BASE_IMAGE=public.ecr.aws/docker/library/python:3.9.7-slim-buster#' session-17-devsecops/Dockerfile
$GIT commit -qam "chore: pin older Flask/gunicorn and python:3.9.7-slim-buster base (vulnerable on purpose)"
rm -rf /tmp/act-artifacts-s17
export LOG2=$S/outputs/act-s17-run2-vulnerable-gate-fails.log
snap 09-act-run2-security-gate-fails --dir "$S" --cols 170 --max-lines 90 <<'EOF'
cd $STAGE && git log --oneline -2 && git show HEAD --format= | grep -E '^[-+][A-Za-z]'
bash $S/scripts/act-run.sh push 2>&1 | sed -r 's/\x1b\[[0-9;]*m//g' > $LOG2; echo "act exit code: ${PIPESTATUS[0]}"
grep -E 'Job (succeeded|failed)|Failure - Main' $LOG2
awk '/Run Main Evaluate policy/{f=1} f&&/\| /{print} /Failure - Main Evaluate policy/{exit}' $LOG2 | cut -c1-168 | grep -v '|\s*$'
grep -cE '/(9\. Push Image|10\. Deploy)' $LOG2
EOF

# ---------------------------------------------------------------- run 3: fixed
$GIT revert --no-edit HEAD >/dev/null
$GIT commit -q --amend -m "fix: Flask 3.1.3, gunicorn 23.0.0, python:3.12-slim base"
rm -rf /tmp/act-artifacts-s17
export LOG3=$S/outputs/act-s17-run3-fixed-pipeline-passes.log
snap 10-act-run3-fixed-pipeline-passes --dir "$S" --cols 170 <<'EOF'
cd $STAGE && git log --oneline -3 && git show HEAD --format= | grep -E '^[-+][A-Za-z]'
bash $S/scripts/act-run.sh push 2>&1 | sed -r 's/\x1b\[[0-9;]*m//g' > $LOG3; echo "act exit code: ${PIPESTATUS[0]}"
grep -E 'Job (succeeded|failed)|Failure - Main' $LOG3
grep -cE 'Success - Main' $LOG3
EOF

snap 11-act-run3-sast-sca-secrets --dir "$S" --cols 170 --max-lines 90 <<'EOF'
awk '/Run Main Bandit/{f=1} f&&/\| /{print} /Success - Main Bandit/{exit}' $LOG3 | grep -E 'No issues|Total lines of code|High: |Medium: ' | head -n 4
awk '/Run Main Semgrep/{f=1} f&&/\| /{print} /Success - Main Semgrep/{exit}' $LOG3 | grep -E 'Findings|Rules run|Targets scanned' | head -n 3
awk '/Run Main pip-audit/{f=1} f&&/\| /{print} /Success - Main pip-audit/{exit}' $LOG3 | grep -vE 'WARNING|\|\s*$'
awk '/Run Main Trivy filesystem/{f=1} f&&/\| /{print} /Success - Main Trivy filesystem/{exit}' $LOG3 | grep -E 'requirements.txt|Total|Report Summary|Number of language' | cut -c1-168
awk '/Run Main Scan git history/{f=1} f&&/\| /{print} /Success - Main Scan git history/{exit}' $LOG3 | grep -E 'INF'
EOF

snap 12-act-run3-image-scan-and-gate-pass --dir "$S" --cols 170 --max-lines 90 <<'EOF'
awk '/Run Main Build image/{f=1} f&&/\| /{print} /Success - Main Build image/{exit}' $LOG3 | grep -E 'user=|naming to' | cut -c1-168
awk '/Run Main Trivy image scan/{f=1} f&&/\| /{print} /Success - Main Trivy image scan/{exit}' $LOG3 | grep -vE 'INFO|WARN|\|\s*$' | cut -c1-168 | head -n 20
awk '/Run Main Evaluate policy/{f=1} f&&/\| /{print} /Success - Main Evaluate policy/{exit}' $LOG3 | cut -c1-168 | grep -v '|\s*$'
EOF

snap 13-act-run3-push-and-deploy --dir "$S" --cols 170 --max-lines 90 <<'EOF'
awk '/Run Main Tag and push the scanned image/{f=1} f&&/\| /{print} /Success - Main Tag and push/{exit}' $LOG3 | grep -E 'Loaded image|push refers|digest|pushed' | cut -c1-168
curl -s http://localhost:5000/v2/v4xsh/s17-devsecops-api/tags/list; echo
awk '/Run Main Create namespace and app secret/{f=1} f&&/\| /{print} /Success - Main Create namespace/{exit}' $LOG3
awk '/Run Main Deploy and wait for rollout/{f=1} f&&/\| /{print} /Success - Main Deploy and wait/{exit}' $LOG3 | cut -c1-168
awk '/Run Main Smoke test/{f=1} f&&/\| /{print} /Success - Main Smoke test/{exit}' $LOG3 | grep -v '|\s*$'
EOF
