#!/usr/bin/env bash
# Final Troubleshooting Challenge - 6 intentionally broken changes on a working copy of the stack (namespace final-ts).
# For each: apply broken -> observe the symptom -> investigate (describe/events/logs/endpoints) -> fix -> verify.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
T=troubleshooting
cd "$P"
IP=$(minikube ip); export IP
OUT="$P/troubleshooting"

snap ts0-baseline --dir "$OUT" <<'EOF'
kubectl apply -f troubleshooting/base/
kubectl rollout status statefulset/taskboard-postgres -n final-ts --timeout=180s
kubectl rollout status deploy/taskboard-backend -n final-ts --timeout=240s
kubectl rollout status deploy/taskboard-frontend -n final-ts --timeout=120s
kubectl get pods,svc,ingress -n final-ts
curl -s -o /dev/null -w 'baseline: GET /api/tasks via ingress -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
EOF

# ---------------------------------------------------------------- 1. wrong image tag -> ImagePullBackOff
snap ts1a-image-pull-broken --dir "$OUT" <<'EOF'
diff troubleshooting/base/03-backend.yaml troubleshooting/scenarios/1-image-pull/broken-deployment.yaml | grep '^[<>].*image:'
kubectl apply -f troubleshooting/scenarios/1-image-pull/broken-deployment.yaml
sleep 45
kubectl get pods -n final-ts -l app=taskboard-backend
kubectl describe pod -n final-ts $(kubectl get pods -n final-ts -l app=taskboard-backend --field-selector=status.phase=Pending -o name | head -n 1 | cut -d/ -f2) | grep -E 'Image:|Reason:|Failed|Back-off' | sort -u | cut -c1-190
kubectl rollout status deploy/taskboard-backend -n final-ts --timeout=5s
EOF
snap ts1b-image-pull-fixed --dir "$OUT" <<'EOF'
minikube image ls | grep taskboard-backend
kubectl apply -f troubleshooting/base/03-backend.yaml
kubectl rollout status deploy/taskboard-backend -n final-ts --timeout=180s
kubectl get pods -n final-ts -l app=taskboard-backend -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready
kubectl rollout history deploy/taskboard-backend -n final-ts | tail -n 4
EOF

# ---------------------------------------------------------------- 2. wrong readiness path -> never Ready, no endpoints, 503
snap ts2a-readiness-broken --dir "$OUT" <<'EOF'
diff troubleshooting/base/03-backend.yaml troubleshooting/scenarios/2-readiness-path/broken-deployment.yaml | grep '^[<>]'
kubectl delete deploy taskboard-backend -n final-ts --wait=true
kubectl apply -f troubleshooting/scenarios/2-readiness-path/broken-deployment.yaml
sleep 40
kubectl get pods -n final-ts -l app=taskboard-backend
kubectl get endpointslices -n final-ts -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
kubectl get events -n final-ts --field-selector reason=Unhealthy --sort-by=.lastTimestamp | tail -n 2 | cut -c1-190
kubectl logs -n final-ts deploy/taskboard-backend --tail=50 | grep readyz | tail -n 2
curl -s -w '  -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks | tail -c 120
EOF
snap ts2b-readiness-fixed --dir "$OUT" <<'EOF'
kubectl apply -f troubleshooting/base/03-backend.yaml
kubectl rollout status deploy/taskboard-backend -n final-ts --timeout=180s
kubectl get pods -n final-ts -l app=taskboard-backend
kubectl get endpointslices -n final-ts -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
curl -s -o /dev/null -w 'GET /api/tasks via ingress -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
EOF

# ---------------------------------------------------------------- 3. Service targetPort mismatch -> 502
snap ts3a-targetport-broken --dir "$OUT" <<'EOF'
diff <(awk 'f{print} /^---/{f=1}' troubleshooting/base/03-backend.yaml) troubleshooting/scenarios/3-service-targetport/broken-service.yaml | grep '^[<>]'
kubectl apply -f troubleshooting/scenarios/3-service-targetport/broken-service.yaml
sleep 5
curl -s -o /dev/null -w 'GET /api/tasks via ingress -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
kubectl get pods -n final-ts -l app=taskboard-backend
kubectl get svc taskboard-backend -n final-ts -o jsonpath='service port={.spec.ports[0].port} targetPort={.spec.ports[0].targetPort}{"\n"}'
kubectl get pods -n final-ts -l app=taskboard-backend -o jsonpath='{.items[0].spec.containers[0].ports[0]}{"\n"}'
kubectl get endpointslices -n final-ts -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*]}{.ports[0].port}{" -> "}{.endpoints[*].addresses[0]}{"\n"}{end}'
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=300 | grep -E 'final-ts.*(connect\(\) failed|Connection refused)' | tail -n 1 | cut -c1-220
EOF
snap ts3b-targetport-fixed --dir "$OUT" <<'EOF'
kubectl apply -f troubleshooting/base/03-backend.yaml
kubectl get svc taskboard-backend -n final-ts -o jsonpath='targetPort={.spec.ports[0].targetPort}{"\n"}'
kubectl get endpointslices -n final-ts -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*]}{.ports[0].port}{" -> "}{.endpoints[*].addresses[0]}{"\n"}{end}'
curl -s -o /dev/null -w 'GET /api/tasks via ingress -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
EOF

# ---------------------------------------------------------------- 4. missing Secret key -> CreateContainerConfigError
snap ts4a-secret-key-broken --dir "$OUT" <<'EOF'
diff troubleshooting/base/03-backend.yaml troubleshooting/scenarios/4-secret-key/broken-deployment.yaml | grep '^[<>]'
kubectl apply -f troubleshooting/scenarios/4-secret-key/broken-deployment.yaml
sleep 25
kubectl get pods -n final-ts -l app=taskboard-backend
kubectl get events -n final-ts --field-selector reason=Failed --sort-by=.lastTimestamp | grep -i secret | tail -n 1 | cut -c1-200
kubectl get secret taskboard-db -n final-ts -o jsonpath='{.data}' | jq -r 'keys[] | "secret key present: \(.)"'
EOF
snap ts4b-secret-key-fixed --dir "$OUT" <<'EOF'
kubectl apply -f troubleshooting/base/03-backend.yaml
kubectl rollout status deploy/taskboard-backend -n final-ts --timeout=180s
kubectl get pods -n final-ts -l app=taskboard-backend
curl -s -o /dev/null -w 'GET /api/tasks via ingress -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
EOF

# ---------------------------------------------------------------- 5. HPA on a Deployment without resource requests -> <unknown>
snap ts5a-hpa-broken --dir "$OUT" <<'EOF'
grep -c 'requests:' troubleshooting/scenarios/5-hpa-no-requests/broken-deployment.yaml
kubectl apply -f troubleshooting/scenarios/5-hpa-no-requests/broken-deployment.yaml -f troubleshooting/scenarios/5-hpa-no-requests/hpa.yaml
kubectl rollout status deploy/taskboard-frontend -n final-ts --timeout=120s
sleep 75
kubectl get hpa taskboard-frontend -n final-ts
kubectl describe hpa taskboard-frontend -n final-ts | grep -E 'FailedGetResourceMetric|missing request' | tail -n 2 | cut -c1-220
kubectl get deploy taskboard-frontend -n final-ts -o jsonpath='resources={.spec.template.spec.containers[0].resources}{"\n"}'
EOF
snap ts5b-hpa-fixed --dir "$OUT" <<'EOF'
kubectl apply -f troubleshooting/base/04-frontend.yaml
kubectl rollout status deploy/taskboard-frontend -n final-ts --timeout=120s
kubectl get deploy taskboard-frontend -n final-ts -o jsonpath='resources={.spec.template.spec.containers[0].resources}{"\n"}'
sleep 90
kubectl get hpa taskboard-frontend -n final-ts
kubectl describe hpa taskboard-frontend -n final-ts | grep -A4 '^Conditions' | cut -c1-160
EOF

# ---------------------------------------------------------------- 6. Ingress points to a non-existent Service -> 503
snap ts6a-ingress-broken --dir "$OUT" <<'EOF'
diff troubleshooting/base/05-ingress.yaml troubleshooting/scenarios/6-ingress-service-name/broken-ingress.yaml | grep '^[<>]'
kubectl apply -f troubleshooting/scenarios/6-ingress-service-name/broken-ingress.yaml
sleep 8
curl -s -w '  -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks | grep -oE '<title>.*</title>|-> HTTP [0-9]+'
curl -s -o /dev/null -w 'GET / (frontend rule still fine) -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/
kubectl describe ingress taskboard -n final-ts | grep -E '/api|/ ' | cut -c1-160
kubectl get svc -n final-ts
EOF
snap ts6b-ingress-fixed --dir "$OUT" <<'EOF'
kubectl apply -f troubleshooting/base/05-ingress.yaml
sleep 8
kubectl describe ingress taskboard -n final-ts | grep -E '/api|/ ' | cut -c1-160
curl -s -o /dev/null -w 'GET /api/tasks via ingress -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
EOF

snap ts7-final-state --dir "$OUT" <<'EOF'
kubectl get pods,svc,ingress,hpa -n final-ts
curl -s -H 'Host: taskboard-ts.local' http://$IP/api/info; echo
EOF
kubectl delete namespace final-ts --wait=false
