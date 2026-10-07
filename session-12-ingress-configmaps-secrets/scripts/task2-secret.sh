#!/usr/bin/env bash
# Session 12 / Task 2 - Secrets: create, inject (env + volume), verify, base64 != encryption
set -u
S=~/devops-homework/session-12-ingress-configmaps-secrets
D=$S/02-secret
cd $D

snap 06-secret-create --dir $S --max-lines 80 <<'EOF'
echo "--- method 1: imperative (value never written to a file)"
kubectl create secret generic api-token-secret -n s12 --from-literal=token=demo-token-12345
echo "--- method 2: declarative YAML (dummy demo values)"
kubectl apply -f db-secret.yaml
kubectl get secrets -n s12
kubectl describe secret yatri-db-secret -n s12
kubectl get secret yatri-db-secret -n s12 -o yaml | grep -v -E "creationTimestamp|resourceVersion|uid|last-applied|{"
EOF

snap 07-secret-pod --dir $S <<'EOF'
kubectl apply -f pod-using-secret.yaml
kubectl wait --for=condition=Ready pod/secret-demo -n s12 --timeout=120s
kubectl get pod secret-demo -n s12
kubectl describe pod secret-demo -n s12 | sed -n '/Environment:/,/Conditions:/p'
EOF

snap 08-secret-verify-inside --dir $S <<'EOF'
echo "--- env vars inside the container (values are already DECODED)"
kubectl exec -n s12 secret-demo -- sh -c 'echo DB_USER=$DB_USER; echo DB_NAME=$DB_NAME; echo DB_PASSWORD=$DB_PASSWORD; echo API_TOKEN=$API_TOKEN'
echo "--- secret volume: one file per key, mode 0400, stored on tmpfs (RAM)"
kubectl exec -n s12 secret-demo -- ls -lL /etc/secrets/db
kubectl exec -n s12 secret-demo -- cat /etc/secrets/db/POSTGRES_USER; echo
kubectl exec -n s12 secret-demo -- sh -c 'mount | grep /etc/secrets/db'
EOF

snap 09-base64-is-not-encryption --dir $S <<'EOF'
kubectl get secret yatri-db-secret -n s12 -o jsonpath='{.data.POSTGRES_PASSWORD}'; echo
kubectl get secret yatri-db-secret -n s12 -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
kubectl get secret yatri-db-secret -n s12 -o go-template='{{range $k,$v := .data}}{{$k}} = {{$v | base64decode}}{{"\n"}}{{end}}'
echo -n "demo-password-not-real" | base64
echo "ZGVtby1wYXNzd29yZC1ub3QtcmVhbA==" | base64 -d; echo
echo "--- anyone with 'get secret' RBAC (or read access to the Git repo) can do the same:"
kubectl auth can-i get secrets -n s12
EOF

snap 10-gitignore-and-scan --dir $S <<'EOF'
cat .gitignore
echo "--- gitleaks finds the base64 secret material in the manifest (this is why real ones never go to Git)"
gitleaks detect --no-git --source . --redact --no-color -v 2>&1 | grep -E "Finding|RuleID|File|leaks found|no leaks" | head -12
EOF
