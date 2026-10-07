#!/usr/bin/env bash
# Final project - GitOps: Argo CD deploys the TaskBoard Helm chart from a Git repository.
# The real GitHub repo is not pushed yet, so a throw-away in-cluster Gitea server plays "GitHub":
# commits are made in a practice clone (~/practice/taskboard-gitops), never in the submission repo.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
B="$HOME/venv-s21/bin/python $P/scripts/browser_shot.py"
GITEA_PWD=$(head -c 64 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 20); export GITEA_PWD
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d); export ARGO_PWD

kubectl delete application taskboard-gitops -n argocd --ignore-not-found
kubectl delete namespace final-gitops final-gitea --ignore-not-found --wait=true
snap 27-gitea-local-git-server --dir "$P" <<'EOF'
kubectl apply -f gitops/local-git-server/gitea.yaml
kubectl rollout status deploy/gitea -n final-gitea --timeout=300s
kubectl exec -n final-gitea deploy/gitea -- gitea admin user create --username vansh --password "$GITEA_PWD" --email vansh@taskboard.local --admin --must-change-password=false
kubectl port-forward -n final-gitea svc/gitea 13001:3000 > /dev/null 2>&1 &
sleep 4
curl -s -u "vansh:$GITEA_PWD" -H 'Content-Type: application/json' -X POST localhost:13001/api/v1/user/repos -d '{"name":"taskboard-gitops","default_branch":"main","private":false}' | jq -c '{full_name, clone_url, default_branch}'
EOF

snap 28-gitops-repo-first-commit --dir "$P" <<'EOF'
rm -rf ~/practice/taskboard-gitops && mkdir -p ~/practice/taskboard-gitops && cp -r helm ~/practice/taskboard-gitops/ && cd ~/practice/taskboard-gitops
git init -q -b main && git config user.name "Vansh Dobhal" && git config user.email vansh@taskboard.local
git add . && git commit -q -m "Add TaskBoard Helm chart (1.0.1) for Argo CD" && git log --oneline
git push "http://vansh:$GITEA_PWD@localhost:13001/vansh/taskboard-gitops.git" main 2>&1 | grep -E "^(To |   [0-9a-f]| * )" | sed "s/$GITEA_PWD/*****/"
curl -s -u "vansh:$GITEA_PWD" localhost:13001/api/v1/repos/vansh/taskboard-gitops/commits | jq -r '.[] | "\(.sha[0:7]) \(.commit.message | split("\n")[0])"'
EOF

snap 29-argocd-app-from-git --dir "$P" <<'EOF'
kubectl create namespace final-gitops --dry-run=client -o yaml | kubectl apply -f -
kubectl -n final-gitops create secret generic taskboard-db-gitops --from-literal=db-password="$(openssl rand -hex 16)" --dry-run=client -o yaml | kubectl apply -f -
grep -vE '^\s*#' gitops/application-local-gitea.yaml
kubectl apply -f gitops/application-local-gitea.yaml
kubectl wait -n argocd application/taskboard-gitops --for=jsonpath='{.status.health.status}'=Healthy --timeout=420s
argocd login localhost:18443 --username admin --password "$ARGO_PWD" --insecure --grpc-web > /dev/null && argocd app get taskboard-gitops --grpc-web | head -n 30
kubectl get pods -n final-gitops
EOF

snap 30-gitops-change-via-commit --dir "$P" <<'EOF'
cd ~/practice/taskboard-gitops && sed -i 's/^backend: {replicaCount: 2}/backend: {replicaCount: 3}/' helm/taskboard/values-gitops.yaml && git diff
git commit -q -am "Scale TaskBoard backend to 3 replicas" && git push "http://vansh:$GITEA_PWD@localhost:13001/vansh/taskboard-gitops.git" main 2>&1 | grep -E "^(To |   [0-9a-f]| * )" | sed "s/$GITEA_PWD/*****/"; git log --oneline | head -n 3
argocd app get taskboard-gitops --grpc-web --refresh > /dev/null
kubectl wait -n argocd application/taskboard-gitops --for=jsonpath='{.status.sync.revision}'=$(git rev-parse HEAD) --timeout=180s
kubectl rollout status deploy/taskboard-backend -n final-gitops --timeout=180s
kubectl get deploy taskboard-backend -n final-gitops
argocd app history taskboard-gitops --grpc-web
EOF

snap 31-gitops-self-heal-and-revert --dir "$P" <<'EOF'
kubectl scale deploy/taskboard-backend -n final-gitops --replicas=1 && sleep 15 && kubectl get deploy taskboard-backend -n final-gitops
cd ~/practice/taskboard-gitops && git revert --no-edit HEAD > /dev/null && git push "http://vansh:$GITEA_PWD@localhost:13001/vansh/taskboard-gitops.git" main 2>&1 | grep -E "^(To |   [0-9a-f]| * )" | sed "s/$GITEA_PWD/*****/"; git log --oneline | head -n 3
argocd app get taskboard-gitops --grpc-web --refresh > /dev/null
kubectl wait -n argocd application/taskboard-gitops --for=jsonpath='{.status.sync.revision}'=$(git rev-parse HEAD) --timeout=180s
sleep 20; kubectl get deploy taskboard-backend -n final-gitops
kubectl get application taskboard-gitops -n argocd -o jsonpath='sync={.status.sync.status} health={.status.health.status} revision={.status.sync.revision}{"\n"}'
EOF

$B "https://localhost:18443/applications/argocd/taskboard-gitops?view=tree&resource=" screenshots/browser/argocd-taskboard-gitops-tree.png --argocd-login "admin:$ARGO_PWD" --wait-ms 5000 --width 1800
$B "https://localhost:18443/applications" screenshots/browser/argocd-applications-final.png --argocd-login "admin:$ARGO_PWD" --wait-ms 4000
pkill -f "port-forward -n final-gitea" || true
