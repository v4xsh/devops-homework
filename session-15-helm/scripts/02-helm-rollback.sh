#!/usr/bin/env bash
# Task 2 - Install -> Upgrade -> Verify -> Upgrade -> Verify -> Rollback -> Verify (+ --atomic auto-rollback)
# Namespace: s15-rollback   Release: rb-web   Chart: ./rollback-demo
D=~/devops-homework/session-15-helm/02-helm-rollback
NS=s15-rollback
cd "$D"
helm uninstall rb-web -n $NS >/dev/null 2>&1
kubectl delete ns $NS --wait >/dev/null 2>&1

# the same verification block is used after every step
VERIFY=$(cat <<'EOV'
kubectl get deploy rb-web -n s15-rollback -o jsonpath='{"image="}{.spec.template.spec.containers[0].image}{"  replicas="}{.spec.replicas}{"  ready="}{.status.readyReplicas}{"\n"}'
kubectl get pods -n s15-rollback -l app.kubernetes.io/instance=rb-web -o custom-columns=POD:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image
kubectl exec client -n s15-rollback -- wget -qO- http://rb-web
kubectl exec client -n s15-rollback -- sh -c 'wget -S -qO /dev/null http://rb-web 2>&1 | grep Server'
helm history rb-web -n s15-rollback
EOV
)

snap 01-lint-template --dir "$D" --max-lines 60 <<'EOF'
cd ~/devops-homework/session-15-helm/02-helm-rollback
helm lint rollback-demo
helm lint rollback-demo -f rollback-demo/values-v2.yaml
helm lint rollback-demo -f rollback-demo/values-v3.yaml
helm template rb-web rollback-demo -n s15-rollback --show-only templates/configmap.yaml
helm template rb-web rollback-demo -f rollback-demo/values-v3.yaml --show-only templates/deployment.yaml | grep -E 'replicas:|image:|checksum|cpu|memory'
EOF

snap 02-install-rev1 --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/02-helm-rollback
helm install rb-web rollback-demo -n s15-rollback --create-namespace --wait --timeout 120s
kubectl run client -n s15-rollback --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl wait pod/client -n s15-rollback --for=condition=Ready --timeout=90s
helm history rb-web -n s15-rollback
EOF

snap 03-verify-rev1 --dir "$D" <<<"$VERIFY"

snap 04-upgrade-rev2 --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/02-helm-rollback
cat rollback-demo/values-v2.yaml
helm upgrade rb-web rollback-demo -n s15-rollback -f rollback-demo/values-v2.yaml --wait --timeout 120s
kubectl rollout status deploy/rb-web -n s15-rollback --timeout=120s
helm history rb-web -n s15-rollback
EOF

sleep 8
snap 05-verify-rev2 --dir "$D" <<<"$VERIFY"

snap 06-upgrade-rev3 --dir "$D" <<'EOF'
cd ~/devops-homework/session-15-helm/02-helm-rollback
cat rollback-demo/values-v3.yaml
helm upgrade rb-web rollback-demo -n s15-rollback -f rollback-demo/values-v3.yaml --wait --timeout 120s
kubectl rollout status deploy/rb-web -n s15-rollback --timeout=120s
helm history rb-web -n s15-rollback
EOF

sleep 8
snap 07-verify-rev3 --dir "$D" <<<"$VERIFY"

snap 08-compare-revisions --dir "$D" --max-lines 80 <<'EOF'
helm get values rb-web -n s15-rollback --revision 1
helm get values rb-web -n s15-rollback --revision 2
helm get values rb-web -n s15-rollback --revision 3
diff <(helm get manifest rb-web -n s15-rollback --revision 2) <(helm get manifest rb-web -n s15-rollback --revision 3)
kubectl get secrets -n s15-rollback -l owner=helm,name=rb-web
kubectl get rs -n s15-rollback -o custom-columns=RS:.metadata.name,DESIRED:.spec.replicas,IMAGE:.spec.template.spec.containers[0].image
EOF

snap 09-rollback-to-rev2 --dir "$D" <<'EOF'
helm rollback rb-web 2 -n s15-rollback --wait --timeout 120s
kubectl rollout status deploy/rb-web -n s15-rollback --timeout=120s
helm history rb-web -n s15-rollback
helm get values rb-web -n s15-rollback
EOF

sleep 8
snap 10-verify-after-rollback --dir "$D" <<<"$VERIFY"

snap 11-atomic-auto-rollback --dir "$D" --max-lines 60 <<'EOF'
cd ~/devops-homework/session-15-helm/02-helm-rollback
helm upgrade rb-web rollback-demo -n s15-rollback -f rollback-demo/values-v3.yaml --set image.tag=9.99-doesnotexist --atomic --timeout 45s
helm history rb-web -n s15-rollback
kubectl get deploy rb-web -n s15-rollback -o jsonpath='{"image="}{.spec.template.spec.containers[0].image}{"  replicas="}{.spec.replicas}{"\n"}'
kubectl exec client -n s15-rollback -- wget -qO- http://rb-web
kubectl get cm rb-web-page -n s15-rollback -o jsonpath='{.data.index\.html}'
EOF

snap 11b-configmap-volume-resync --dir "$D" <<'EOF'
date +%T; kubectl exec client -n s15-rollback -- wget -qO- http://rb-web
sleep 90
date +%T; kubectl exec client -n s15-rollback -- wget -qO- http://rb-web
kubectl get pods -n s15-rollback -l app.kubernetes.io/instance=rb-web -o custom-columns=POD:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image,RESTARTS:.status.containerStatuses[0].restartCount
EOF

sleep 5
snap 12-cleanup --dir "$D" <<'EOF'
helm uninstall rb-web -n s15-rollback --wait
kubectl delete pod client -n s15-rollback --now
helm list -n s15-rollback --all
kubectl delete namespace s15-rollback --wait
kubectl get ns s15-rollback
EOF
