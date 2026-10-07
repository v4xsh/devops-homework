#!/usr/bin/env bash
# Task 3 - Mini project: package and deploy the Notes app with Helm (dev + prod values)
# Namespace: s15-mini   Releases: notes-dev, notes-prod   Chart: ./notes-chart
D=~/devops-homework/session-15-helm/mini-project
NS=s15-mini
cd "$D"
helm uninstall notes-dev notes-prod -n $NS >/dev/null 2>&1
kubectl delete ns $NS --wait >/dev/null 2>&1
rm -rf dist

snap 01-chart-structure-lint --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/mini-project
tree -a notes-chart
helm lint notes-chart
helm lint notes-chart -f notes-chart/values-prod.yaml --strict
EOF

snap 02-template-dev --dir "$D" --max-lines 80 <<'EOF'
cd ~/devops-homework/session-15-helm/mini-project
helm template notes-dev notes-chart -n s15-mini --show-only templates/configmap.yaml
helm template notes-dev notes-chart -n s15-mini --show-only templates/service.yaml
helm template notes-dev notes-chart --set image.repository="" 2>&1 | grep Error
EOF

snap 03-template-dev-vs-prod --dir "$D" --max-lines 90 <<'EOF'
cd ~/devops-homework/session-15-helm/mini-project
helm template notes notes-chart > /tmp/s15-dev.yaml
helm template notes notes-chart -f notes-chart/values-prod.yaml > /tmp/s15-prod.yaml
diff /tmp/s15-dev.yaml /tmp/s15-prod.yaml | grep -E '^[<>]' | grep -v checksum
EOF

snap 04-install-dev --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/mini-project
helm install notes-dev notes-chart -n s15-mini --create-namespace --wait --timeout 120s
kubectl get pods,svc,configmap -n s15-mini -l app.kubernetes.io/instance=notes-dev
curl -s http://$(minikube ip):31590
kubectl exec -n s15-mini deploy/notes-dev-deploy -- sh -c 'env | grep -E "APP_NAME|ENVIRONMENT|LOG_LEVEL" | sort'
EOF

snap 05-install-prod --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/mini-project
helm install notes-prod notes-chart -n s15-mini -f notes-chart/values-prod.yaml --wait --timeout 120s
kubectl run client -n s15-mini --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl wait pod/client -n s15-mini --for=condition=Ready --timeout=90s
kubectl get pods,svc -n s15-mini -l app.kubernetes.io/instance=notes-prod
kubectl exec -n s15-mini client -- wget -qO- http://notes-prod-svc
EOF

snap 06-dev-vs-prod-side-by-side --dir "$D" <<'EOF'
helm list -n s15-mini
kubectl get deploy -n s15-mini -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image,ENV:.metadata.labels.environment,LIMITS:.spec.template.spec.containers[0].resources.limits
kubectl get svc -n s15-mini
helm get values notes-prod -n s15-mini
kubectl get cm notes-prod-config -n s15-mini -o jsonpath='{.data}' ; echo
EOF

snap 07-upgrade-dev-to-prod-values --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/mini-project
helm upgrade notes-dev notes-chart -n s15-mini -f notes-chart/values-prod.yaml --wait --timeout 120s
kubectl get pods -n s15-mini -l app.kubernetes.io/instance=notes-dev
kubectl get svc notes-dev-svc -n s15-mini
kubectl exec -n s15-mini client -- wget -qO- http://notes-dev-svc
helm history notes-dev -n s15-mini
EOF

snap 08-bad-upgrade --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/mini-project
helm upgrade notes-dev notes-chart -n s15-mini -f notes-chart/values-prod.yaml --set image.tag=broken-tag-does-not-exist
sleep 25
kubectl get pods -n s15-mini -l app.kubernetes.io/instance=notes-dev
kubectl get deploy notes-dev-deploy -n s15-mini
helm history notes-dev -n s15-mini
EOF

snap 09-rollback-to-rev2 --dir "$D" <<'EOF'
helm rollback notes-dev 2 -n s15-mini --wait --timeout 120s
kubectl rollout status deploy/notes-dev-deploy -n s15-mini --timeout=120s
sleep 5
kubectl get pods -n s15-mini -l app.kubernetes.io/instance=notes-dev
kubectl get deploy notes-dev-deploy -n s15-mini -o jsonpath='{"image="}{.spec.template.spec.containers[0].image}{"  replicas="}{.spec.replicas}{"\n"}'
kubectl exec -n s15-mini client -- wget -qO- http://notes-dev-svc
helm history notes-dev -n s15-mini
EOF

snap 10-package --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/mini-project
helm package notes-chart -d dist
tar -tzf dist/notes-chart-0.1.0.tgz
helm show chart dist/notes-chart-0.1.0.tgz
EOF

snap 11-cleanup --dir "$D" <<'EOF'
helm uninstall notes-dev notes-prod -n s15-mini --wait
kubectl delete pod client -n s15-mini --now
kubectl get pods,services,configmaps -n s15-mini
helm list -n s15-mini --all
kubectl delete namespace s15-mini --wait
EOF
rm -f /tmp/s15-dev.yaml /tmp/s15-prod.yaml
