#!/usr/bin/env bash
# Evidence captured after run 3: image-scan/gate excerpt of the run-3 log and a hardening check
# of the running Deployment in namespace s17 (from my own terminal, outside the pipeline).
set -euo pipefail
export PATH="$HOME/venvs/s1617/bin:$PATH"
export S=~/devops-homework/session-17-devsecops
export LOG3=$S/outputs/act-s17-run3-fixed-pipeline-passes.log
cd "$S"

# the job prefix "[Session 17 - ...]   | " is stripped so the Trivy table fits on screen
snap 12-act-run3-image-scan-and-gate-pass --dir "$S" --cols 150 --max-lines 90 <<'EOF'
awk '/Run Main Build image/{f=1} f&&/\| /{print} /Success - Main Build image/{exit}' $LOG3 | grep -E 'user=|naming to' | sed 's/^.*\]   | //'
awk '/Run Main Trivy image scan/{f=1} f&&/\| /{print} /Success - Main Trivy image scan/{exit}' $LOG3 | sed 's/^.*\]   | //' | grep -vE 'INFO|WARN|^\s*$|├' | head -n 22
awk '/Run Main Evaluate policy/{f=1} f&&/\| /{print} /Success - Main Evaluate policy/{exit}' $LOG3 | sed 's/^.*\]   | //' | grep -vE '^\s*$|\.json$|\.xml$'
EOF

snap 14-k8s-hardening-verification --dir "$S" --cols 160 --max-lines 90 <<'EOF'
kubectl get deploy,pods,svc -n s17 -o wide
kubectl get deploy devsecops-api -n s17 -o jsonpath='{.spec.template.spec.securityContext}{"\n"}{.spec.template.spec.containers[0].securityContext}{"\n"}{.spec.template.spec.containers[0].resources}{"\n"}'
POD=$(kubectl get pod -n s17 -l app=devsecops-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n s17 $POD -- id
kubectl exec -n s17 $POD -- sh -c 'touch /app/hacked 2>&1; touch /tmp/ok && echo "/tmp (emptyDir) is writable"'
kubectl exec -n s17 $POD -- sh -c 'grep -E "^(CapEff|NoNewPrivs)" /proc/1/status'
kubectl get secret devsecops-api -n s17 -o jsonpath='{.data}' | sed -E 's/"app-secret-key":"[^"]+"/"app-secret-key":"<base64 value hidden>"/'; echo
(kubectl port-forward -n s17 svc/devsecops-api 8102:80 >/tmp/pf-s17.log 2>&1 &) ; sleep 3
curl -s -i localhost:8102/health | grep -E 'HTTP/|X-Content|X-Frame|Content-Security|status'
curl -s -X POST localhost:8102/api/notes -H 'Content-Type: application/json' -d '{"title":""}'; echo
pkill -f "port-forward -n s17" || true
EOF
