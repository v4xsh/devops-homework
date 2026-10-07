#!/usr/bin/env bash
# Verify, from my own terminal (outside the pipeline), what the act run produced:
# the image in the registry and the running Deployment in namespace s16.
set -euo pipefail
S=~/devops-homework/session-16-cicd-github-actions
TAG=$(git -C ~/act-stage/session-16-cicd-github-actions/devops-homework rev-parse --short HEAD~1)
export TAG

snap 10-verify-registry-and-k8s-from-host --dir "$S" --cols 160 <<'EOF'
echo "image tag built by the passing run: $TAG"
docker pull -q localhost:5000/v4xsh/s16-calculator-api:$TAG
kubectl rollout history deployment/calculator-api -n s16
kubectl get pods -n s16 -l app=calculator-api -o custom-columns=POD:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready
(kubectl port-forward -n s16 svc/calculator-api 8101:80 >/tmp/pf-s16.log 2>&1 &) ; sleep 3
curl -s localhost:8101/health; echo
curl -s "localhost:8101/api/subtract?a=10&b=4"; echo
curl -s localhost:8101/version; echo
pkill -f "port-forward -n s16" || true
EOF
