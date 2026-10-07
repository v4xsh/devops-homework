#!/usr/bin/env bash
# Second pass for scenarios 3 and 5. In the first pass the "fixed" check ran before ingress-nginx had picked up the
# corrected endpoints, and the HPA event was captured before metrics-server had data. Same broken files; this time
# verification polls until the expected state is reached and prints how many attempts it took.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
IP=$(minikube ip); export IP
OUT="$P/troubleshooting"
kubectl wait --for=delete namespace/final-ts --timeout=180s 2>/dev/null
kubectl apply -f troubleshooting/base/ >/dev/null
kubectl rollout status deploy/taskboard-backend -n final-ts --timeout=300s >/dev/null
kubectl rollout status deploy/taskboard-frontend -n final-ts --timeout=120s >/dev/null

snap ts3c-targetport-rerun --dir "$OUT" <<'EOF'
kubectl apply -f troubleshooting/scenarios/3-service-targetport/broken-service.yaml
sleep 10
curl -s -o /dev/null -w 'broken: GET /api/tasks via ingress -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=200 | grep -E 'Connection refused' | grep 8080 | tail -n 1 | cut -c1-230
kubectl apply -f troubleshooting/base/03-backend.yaml
kubectl get endpointslices -n final-ts -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*]}{.ports[0].port}{" -> "}{.endpoints[*].addresses[0]}{"\n"}{end}'
for i in $(seq 1 36); do c=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: taskboard-ts.local' http://$IP/api/tasks); echo "fixed, attempt $i (5s apart): GET /api/tasks -> HTTP $c"; [ "$c" = 200 ] && break; sleep 5; done
EOF

snap ts5c-hpa-rerun --dir "$OUT" <<'EOF'
kubectl apply -f troubleshooting/scenarios/5-hpa-no-requests/broken-deployment.yaml -f troubleshooting/scenarios/5-hpa-no-requests/hpa.yaml
kubectl rollout status deploy/taskboard-frontend -n final-ts --timeout=120s
sleep 150
kubectl get hpa taskboard-frontend -n final-ts
kubectl describe hpa taskboard-frontend -n final-ts | grep -E 'missing request|ScalingActive' | tail -n 2 | cut -c1-230
kubectl apply -f troubleshooting/base/04-frontend.yaml
kubectl rollout status deploy/taskboard-frontend -n final-ts --timeout=120s
for i in $(seq 1 30); do kubectl get hpa taskboard-frontend -n final-ts --no-headers | grep -q 'cpu: [0-9]' && break; sleep 10; done; echo "polled $i times (10s apart) until the HPA had a CPU value"
kubectl get hpa taskboard-frontend -n final-ts
kubectl describe hpa taskboard-frontend -n final-ts | grep -E 'ScalingActive' | cut -c1-160
EOF
kubectl delete namespace final-ts --wait=false
