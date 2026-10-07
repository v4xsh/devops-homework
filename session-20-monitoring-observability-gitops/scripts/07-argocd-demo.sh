#!/usr/bin/env bash
# Session 20 / Task 3 - Argo CD install, Application from a public Git repo, sync, self-heal, drift detection.
set -u
S=~/devops-homework/session-20-monitoring-observability-gitops
cd "$S"
B="$HOME/venv-s21/bin/python $S/scripts/browser_shot.py"

# label fix for the ServiceMonitor (see README "lesson learned")
snap 15-servicemonitor-honorlabels --dir "$S" <<'EOF'
scripts/promq.sh 'count by (endpoint, exported_endpoint) (app_requests_total{namespace="s20-app"})'
kubectl apply -f task1-monitoring/k8s/servicemonitor.yaml
sleep 45
scripts/promq.sh 'sum by (endpoint, status) (rate(app_requests_total{namespace="s20-app"}[1m]))'
EOF

snap 20-argocd-install --dir "$S" <<'EOF'
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>&1 | tail -n 6
kubectl scale deploy -n argocd argocd-dex-server argocd-notifications-controller --replicas=0
kubectl wait -n argocd --for=condition=Available deploy/argocd-server deploy/argocd-repo-server deploy/argocd-redis --timeout=600s
kubectl rollout status -n argocd statefulset/argocd-application-controller --timeout=300s
kubectl get pods -n argocd
argocd version --client --short
EOF

ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
export ARGO_PWD
until curl -sk https://localhost:18443/healthz >/dev/null; do sleep 3; done

snap 21-argocd-app-synced --dir "$S" <<'EOF'
argocd login localhost:18443 --username admin --password "$ARGO_PWD" --insecure --grpc-web
cat task3-gitops/argocd/application-instructor-repo.yaml | grep -vE '^\s*#'
kubectl apply -f task3-gitops/argocd/application-instructor-repo.yaml
kubectl wait -n argocd application/s20-gitops-instructor --for=jsonpath='{.status.health.status}'=Healthy --timeout=300s
kubectl get application -n argocd s20-gitops-instructor -o jsonpath='sync={.status.sync.status} health={.status.health.status} revision={.status.sync.revision}{"\n"}'
argocd app get s20-gitops-instructor --grpc-web | head -n 25
kubectl get deploy,svc -n s20-app -l app=session20-gitops-app
EOF

snap 22-git-history-source-of-truth --dir "$S" <<'EOF'
cd ~/devops-heros-ref 2>/dev/null || git clone -q https://github.com/Nency-Ravaliya/devops-heros.git ~/devops-heros-ref
cd ~/devops-heros-ref && git pull -q && git log --oneline -4 -- session20-monitoring-observability-gitops/07-argocd/app
git -C ~/devops-heros-ref show --stat --format='%h %an %ad %s' HEAD -- session20-monitoring-observability-gitops/07-argocd/app | head -n 4
git -C ~/devops-heros-ref show HEAD -- session20-monitoring-observability-gitops/07-argocd/app/deployment.yaml | tail -n 6
kubectl get deploy session20-gitops-app -n s20-app -o jsonpath='cluster replicas = {.spec.replicas}{"\n"}'
EOF

snap 23-argocd-self-heal --dir "$S" <<'EOF'
kubectl scale deploy/session20-gitops-app -n s20-app --replicas=1
kubectl get deploy session20-gitops-app -n s20-app
sleep 15
kubectl get deploy session20-gitops-app -n s20-app
kubectl delete svc session20-gitops-app -n s20-app
sleep 15
kubectl get svc session20-gitops-app -n s20-app
argocd app history s20-gitops-instructor --grpc-web | tail -n 4
kubectl get events -n argocd --field-selector involvedObject.name=s20-gitops-instructor --sort-by=.lastTimestamp | tail -n 6 | cut -c1-200
EOF

snap 24-argocd-drift-detection --dir "$S" <<'EOF'
kubectl patch application s20-gitops-instructor -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":false}}}}'
kubectl set image deploy/session20-gitops-app -n s20-app app=nginx:1.26-alpine
kubectl scale deploy/session20-gitops-app -n s20-app --replicas=2
sleep 20
kubectl get application s20-gitops-instructor -n argocd -o jsonpath='sync={.status.sync.status} health={.status.health.status}{"\n"}'
argocd app diff s20-gitops-instructor --grpc-web
argocd app sync s20-gitops-instructor --grpc-web --timeout 120 | tail -n 6
kubectl patch application s20-gitops-instructor -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
kubectl rollout status deploy/session20-gitops-app -n s20-app --timeout=120s
kubectl get application s20-gitops-instructor -n argocd -o jsonpath='sync={.status.sync.status} health={.status.health.status}{"\n"}'
kubectl get deploy session20-gitops-app -n s20-app -o jsonpath='replicas={.spec.replicas} image={.spec.template.spec.containers[0].image}{"\n"}'
EOF

snap 25-own-gitops-manifests --dir "$S" <<'EOF'
tree task3-gitops
grep -vE '^\s*#' task3-gitops/argocd/application-devops-homework.yaml
kubectl apply --dry-run=server -f task3-gitops/gitops/s20-metrics-app/
kubectl apply --dry-run=server -f task3-gitops/argocd/application-devops-homework.yaml
EOF

# real browser captures of the Argo CD UI
$B "https://localhost:18443/applications" screenshots/browser/argocd-applications.png --argocd-login "admin:$ARGO_PWD" --wait-ms 4000
$B "https://localhost:18443/applications/argocd/s20-gitops-instructor?view=tree&resource=" screenshots/browser/argocd-app-tree.png --argocd-login "admin:$ARGO_PWD" --wait-ms 5000
