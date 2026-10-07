#!/usr/bin/env bash
# Scenario 3 deep dive: after fixing the Service targetPort, the Ingress kept answering 502 for 3+ minutes (ts3c).
# Look inside ingress-nginx (its /dbg tool prints the upstream endpoints it is really using) to find out why.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
IP=$(minikube ip); export IP
OUT="$P/troubleshooting"
kubectl wait --for=delete namespace/final-ts --timeout=180s 2>/dev/null
kubectl apply -f troubleshooting/base/ >/dev/null
kubectl rollout status deploy/taskboard-backend -n final-ts --timeout=300s >/dev/null
kubectl rollout status deploy/taskboard-frontend -n final-ts --timeout=120s >/dev/null
sleep 10

snap ts3d-targetport-ingress-upstream --dir "$OUT" --max-lines 90 <<'EOF'
CTRL=$(kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o name | head -n 1); echo "$CTRL"
kubectl exec -n ingress-nginx $CTRL -- /dbg backends list | grep final-ts
kubectl apply -f troubleshooting/scenarios/3-service-targetport/broken-service.yaml
sleep 10
kubectl exec -n ingress-nginx $CTRL -- /dbg backends get final-ts-taskboard-backend-http | jq -c '[.endpoints[] | "\(.address):\(.port)"]'
kubectl apply -f troubleshooting/base/03-backend.yaml
sleep 20
kubectl get endpointslices -n final-ts -l kubernetes.io/service-name=taskboard-backend -o jsonpath='EndpointSlice port now: {.items[0].ports[0].port}{"\n"}'
kubectl exec -n ingress-nginx $CTRL -- /dbg backends get final-ts-taskboard-backend-http | jq -c '[.endpoints[] | "\(.address):\(.port)"]'
curl -s -o /dev/null -w 'after Service fix only: GET /api/tasks -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
kubectl rollout restart deploy/taskboard-backend -n final-ts && kubectl rollout status deploy/taskboard-backend -n final-ts --timeout=180s
sleep 10
kubectl exec -n ingress-nginx $CTRL -- /dbg backends get final-ts-taskboard-backend-http | jq -c '[.endpoints[] | "\(.address):\(.port)"]'
curl -s -o /dev/null -w 'after new pods (new endpoint addresses): GET /api/tasks -> HTTP %{http_code}\n' -H 'Host: taskboard-ts.local' http://$IP/api/tasks
EOF
kubectl delete namespace final-ts --wait=false
