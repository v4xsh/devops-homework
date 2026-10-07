#!/usr/bin/env bash
# Run the workflow end-to-end with act and capture the evidence with `snap`.
set -euo pipefail
export PATH="$HOME/venvs/s1617/bin:$PATH"
S=~/devops-homework/session-16-cicd-github-actions
STAGE=~/act-stage/session-16-cicd-github-actions/devops-homework
LOG=$S/outputs/act-s16-main-run.log
export S STAGE LOG
mkdir -p "$S/outputs"

bash "$S/scripts/act-stage.sh" session-16-cicd-github-actions session16-ci-cd.yml
rm -rf /tmp/act-artifacts-s16
kubectl delete namespace s16 --ignore-not-found --wait=true

# 1) the job graph act reads from the workflow file
snap 03-act-workflow-graph --dir "$S" --cols 170 <<'EOF'
cd $STAGE && git log --oneline -1 && git remote -v | head -1
act -l -W .github/workflows/session16-ci-cd.yml
EOF

# 2) full run (push event on main) - the full log is kept in outputs/act-s16-main-run.log
snap 04-act-full-pipeline-run --dir "$S" --cols 170 <<'EOF'
cd $STAGE
bash $S/scripts/act-run.sh 2>&1 | sed -r 's/\x1b\[[0-9;]*m//g' > $LOG; echo "act exit code: ${PIPESTATUS[0]}"
wc -l $LOG
grep -E 'Job (succeeded|failed)' $LOG
grep -cE 'Success - Main' $LOG
EOF

# 3) excerpts of the same log, one per pipeline concept
snap 05-act-test-matrix-coverage --dir "$S" --cols 170 --max-lines 80 <<'EOF'
grep -E 'Matrix: map|Successfully set up CPython' $LOG | sort
awk '/Test \(Python 3.12\).*Run Main Run unit tests/{f=1} f&&/Test \(Python 3.12\)/{print} /Test \(Python 3.12\).*Success - Main Run unit tests/{exit}' $LOG | grep -E '\| ' | cut -c1-165 | head -n 45
EOF

snap 06-act-artifacts-and-secret-masking --dir "$S" --cols 170 <<'EOF'
grep -E 'Upload coverage|Artifact .* successfully finalized|Artifact name is valid|Uploaded bytes|docker-image' $LOG | grep -vE 'docker cp|docker exec' | head -n 16
grep -A6 'Run Main Show downloaded coverage summary' $LOG | grep -E '\| '
grep -A5 'Run Main Use a repository secret' $LOG | grep -E '\| '
find /tmp/act-artifacts-s16 -type f | sort
EOF

snap 07-act-push-to-registry --dir "$S" --cols 170 <<'EOF'
awk '/Run Main Tag and push/{f=1} f&&/\| /{print} /Success - Main Tag and push/{exit}' $LOG | cut -c1-160 | tail -n 14
curl -s http://localhost:5000/v2/_catalog; echo
curl -s http://localhost:5000/v2/v4xsh/s16-calculator-api/tags/list; echo
EOF

snap 08-act-deploy-to-kubernetes --dir "$S" --cols 170 --max-lines 80 <<'EOF'
grep -A3 'Run Main Use kubeconfig from secret' $LOG | grep -E '\| '
awk '/Run Main Apply manifests and roll out/{f=1} f&&/\| /{print} /Success - Main Apply manifests/{exit}' $LOG | cut -c1-165
awk '/Run Main Smoke test through the Service/{f=1} f&&/\| /{print} /Success - Main Smoke test through/{exit}' $LOG
kubectl get deploy,rs,pods,svc -n s16 -o wide
kubectl get deploy calculator-api -n s16 -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
EOF

# 4) negative run: a commit that breaks a unit test -> test jobs fail, build/push/deploy never start (needs:)
cd "$STAGE"
sed -i 's/return a + b/return a - b  # bug introduced on purpose/' session-16-cicd-github-actions/app/calculator.py
git -c user.name="Vansh Dobhal" -c user.email="vanshdobhal11@gmail.com" commit -qam "demo: introduce a bug in add()"
FLOG=$S/outputs/act-s16-failing-tests-run.log
export FLOG
snap 09-act-failing-test-blocks-pipeline --dir "$S" --cols 170 <<'EOF'
cd $STAGE && git log --oneline -2 && git show HEAD --format= | grep '^[-+] '
bash $S/scripts/act-run.sh 2>&1 | sed -r 's/\x1b\[[0-9;]*m//g' > $FLOG; echo "act exit code: ${PIPESTATUS[0]}"
grep -E 'Test \(Python 3.12\).*\| (FAILED|E   |=+ .*(failed|passed))' $FLOG | cut -c1-160 | head -n 8
grep -E 'Job (succeeded|failed)|Failure - Main' $FLOG
grep -cE '/(Build Docker image|Push image to registry|Deploy to Kubernetes) *\]' $FLOG
EOF
