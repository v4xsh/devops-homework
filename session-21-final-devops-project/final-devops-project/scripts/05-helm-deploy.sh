#!/usr/bin/env bash
# Final project - Helm chart: lint, template, install into final-app, helm test, ingress, HPA under load.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
IP=$(minikube ip); export IP
B="$HOME/venv-s21/bin/python $P/scripts/browser_shot.py"

snap 16-helm-lint-template --dir "$P" <<'EOF'
helm version --short
helm lint helm/taskboard -f helm/taskboard/values-prod.yaml
helm lint helm/taskboard
helm template taskboard helm/taskboard -n final-app | grep -E '^kind:' | sort | uniq -c
helm template taskboard helm/taskboard -n final-app -f helm/taskboard/values-prod.yaml | grep -E 'replicas:|minReplicas|maxReplicas|host:|secretName' | sort | uniq -c
EOF

snap 17-helm-install --dir "$P" --max-lines 80 <<'EOF'
helm upgrade --install taskboard helm/taskboard -n final-app --create-namespace --wait --timeout 6m
helm list -n final-app
kubectl get pods,svc,ingress,hpa,pvc -n final-app -o wide | cut -c1-170
kubectl get configmap -n monitoring -l grafana_dashboard=1 -o name
EOF

snap 18-helm-test-and-ingress --dir "$P" <<'EOF'
helm test taskboard -n final-app --logs | tail -n 12
curl -s -H 'Host: taskboard.local' http://$IP/api/info; echo
for t in "Plan sprint" "Write Terraform" "Configure Argo CD"; do curl -s -o /dev/null -w "POST /api/tasks ($t) -> %{http_code}\n" -H 'Host: taskboard.local' -H 'Content-Type: application/json' -X POST http://$IP/api/tasks -d "{\"title\":\"$t\",\"priority\":\"HIGH\",\"assignee\":\"Vansh\"}"; done
curl -s -H 'Host: taskboard.local' -X PUT http://$IP/api/tasks/1 -H 'Content-Type: application/json' -d '{"status":"DONE"}' | jq -c '{id,title,status}'
curl -s -H 'Host: taskboard.local' http://$IP/api/tasks/stats; echo
curl -s -o /dev/null -w 'GET / (frontend) -> HTTP %{http_code}\n' -H 'Host: taskboard.local' http://$IP/
curl -s -o /dev/null -w 'GET /metrics via ingress -> HTTP %{http_code} content-type=%{content_type} (served by the frontend SPA, backend /metrics is not public)\n' -H 'Host: taskboard.local' http://$IP/metrics
EOF

$B "http://taskboard.local/" screenshots/browser/taskboard-ui-ingress-helm.png --resolve "taskboard.local=$IP" --wait-ms 3000 --height 950

# ---- HPA under load ----
kubectl apply -f scripts/loadgen-pod.yaml
snap 19-hpa-scale-up --dir "$P" <<'EOF'
kubectl get hpa taskboard-backend -n final-app
kubectl get pod loadgen -n final-app
sleep 75
kubectl top pods -n final-app -l app.kubernetes.io/component=backend
kubectl get hpa taskboard-backend -n final-app
sleep 60
kubectl get hpa taskboard-backend -n final-app
kubectl get deploy taskboard-backend -n final-app
kubectl describe hpa taskboard-backend -n final-app | grep -E 'SuccessfulRescale|New size' | tail -n 4
EOF
kubectl -n final-app delete pod loadgen --now
snap 20-hpa-scale-down --dir "$P" <<'EOF'
sleep 150
kubectl get hpa taskboard-backend -n final-app
kubectl describe hpa taskboard-backend -n final-app | grep -E 'SuccessfulRescale' | tail -n 3
EOF
