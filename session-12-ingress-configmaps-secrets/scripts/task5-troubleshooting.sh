#!/usr/bin/env bash
# Session 12 / Task 5 - troubleshooting drills from the instructor's troubleshooting folders
# namespace: s12-troubleshoot
set -u
D=~/devops-homework/session-12-ingress-configmaps-secrets/troubleshooting
cd $D

########## Scenario 1: Service with empty endpoints ##########
snap 01-empty-endpoints-problem --dir $D <<'EOF'
kubectl apply -f ../00-namespace/namespaces.yaml
kubectl apply -f manifests/01-backend.yaml
kubectl rollout status deployment/yatri-backend -n s12-troubleshoot --timeout=120s
kubectl wait --for=condition=Ready pod/debug-client -n s12-troubleshoot --timeout=120s
kubectl apply -f manifests/01-empty-endpoints-broken.yaml
kubectl get pods,svc -n s12-troubleshoot
kubectl exec -n s12-troubleshoot debug-client -- curl -s -m 5 http://broken-backend-service || echo "curl exit code $? -> service resolves but nothing answers"
EOF

snap 02-empty-endpoints-diagnose --dir $D <<'EOF'
kubectl get endpoints broken-backend-service -n s12-troubleshoot
kubectl get endpointslices -n s12-troubleshoot -l kubernetes.io/service-name=broken-backend-service
kubectl describe svc broken-backend-service -n s12-troubleshoot | grep -E "Selector|Endpoints|TargetPort"
kubectl get pods -n s12-troubleshoot --show-labels
kubectl get pods -n s12-troubleshoot -l app=wrong-backend-name
kubectl get pods -n s12-troubleshoot -l app=yatri-backend -o wide
EOF

snap 03-empty-endpoints-fixed --dir $D <<'EOF'
diff manifests/01-empty-endpoints-broken.yaml manifests/01-empty-endpoints-fixed.yaml
kubectl apply -f manifests/01-empty-endpoints-fixed.yaml
sleep 3
kubectl describe svc broken-backend-service -n s12-troubleshoot | grep -E "Selector|Endpoints"
kubectl get endpointslices -n s12-troubleshoot -l kubernetes.io/service-name=broken-backend-service
for i in 1 2 3 4; do kubectl exec -n s12-troubleshoot debug-client -- curl -s -m 5 http://broken-backend-service; done
EOF

########## Scenario 2: Secret base64 trailing-newline gotcha ##########
snap 04-secret-newline-problem --dir $D --max-lines 80 <<'EOF'
kubectl apply -f manifests/02-postgres.yaml
kubectl wait --for=condition=Ready pod/postgres -n s12-troubleshoot --timeout=180s
kubectl apply -f manifests/02-app-secret-broken.yaml -f manifests/02-app-client.yaml
kubectl wait --for=condition=Ready pod/app-client -n s12-troubleshoot --timeout=120s
kubectl exec -n s12-troubleshoot app-client -- psql -c "select current_user, version();"
kubectl logs postgres -n s12-troubleshoot --tail=3
EOF

snap 05-secret-newline-diagnose --dir $D <<'EOF'
echo "--- the developer swears the password is right... look at the raw bytes"
kubectl get secret app-db-secret -n s12-troubleshoot -o jsonpath='{.data.PGPASSWORD}'; echo
kubectl get secret app-db-secret -n s12-troubleshoot -o jsonpath='{.data.PGPASSWORD}' | base64 -d | xxd
kubectl exec -n s12-troubleshoot app-client -- sh -c 'printf %s "$PGPASSWORD" | wc -c'
echo "--- reproduce how the value was produced"
echo "mypassword" | xxd
echo "mypassword" | base64
echo -n "mypassword" | base64
EOF

snap 06-secret-newline-fixed --dir $D <<'EOF'
diff manifests/02-app-secret-broken.yaml manifests/02-app-secret-fixed.yaml
kubectl apply -f manifests/02-app-secret-fixed.yaml
echo "--- env vars are read only at container start -> recreate the pod"
kubectl delete pod app-client -n s12-troubleshoot --wait=true
kubectl apply -f manifests/02-app-client.yaml
kubectl wait --for=condition=Ready pod/app-client -n s12-troubleshoot --timeout=120s
kubectl exec -n s12-troubleshoot app-client -- sh -c 'printf %s "$PGPASSWORD" | wc -c'
kubectl exec -n s12-troubleshoot app-client -- psql -c "select current_user, current_database();"
EOF

########## Scenario 3: broken image tag during a rolling update ##########
snap 07-broken-image-problem --dir $D <<'EOF'
kubectl apply -f manifests/03-rollout-v1.yaml
kubectl rollout status deployment/yatri-web -n s12-troubleshoot --timeout=120s
kubectl apply -f manifests/03-broken-image.yaml
kubectl rollout status deployment/yatri-web -n s12-troubleshoot --timeout=40s
kubectl get pods -n s12-troubleshoot -l app=yatri-web -o wide
kubectl get rs -n s12-troubleshoot -l app=yatri-web -o wide
EOF

snap 08-broken-image-diagnose --dir $D <<'EOF'
BAD=$(kubectl get pods -n s12-troubleshoot -l app=yatri-web,version=broken-v3 -o jsonpath='{.items[0].metadata.name}'); echo "failing pod: $BAD"
kubectl get pod $BAD -n s12-troubleshoot -o jsonpath='{.status.containerStatuses[0].state.waiting}{"\n"}'
kubectl describe pod $BAD -n s12-troubleshoot | sed -n '/Events:/,$p' | tail -8
kubectl get events -n s12-troubleshoot --field-selector involvedObject.name=$BAD --sort-by=.lastTimestamp | tail -4
EOF

snap 09-broken-image-fixed --dir $D <<'EOF'
kubectl rollout history deployment/yatri-web -n s12-troubleshoot
kubectl rollout undo deployment/yatri-web -n s12-troubleshoot
kubectl rollout status deployment/yatri-web -n s12-troubleshoot --timeout=120s
kubectl get pods -n s12-troubleshoot -l app=yatri-web -L version
kubectl get deploy yatri-web -n s12-troubleshoot -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
EOF

########## Scenario 4: Deployment selector does not match template labels ##########
snap 10-selector-mismatch --dir $D <<'EOF'
kubectl apply -f manifests/04-selector-mismatch-broken.yaml
kubectl get deploy selector-error-demo -n s12-troubleshoot
diff manifests/04-selector-mismatch-broken.yaml manifests/04-selector-mismatch-fixed.yaml
kubectl apply -f manifests/04-selector-mismatch-fixed.yaml
kubectl rollout status deployment/selector-error-demo -n s12-troubleshoot --timeout=120s
kubectl get deploy,pods -n s12-troubleshoot -l app=correct-app-name
EOF
