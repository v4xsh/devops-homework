#!/usr/bin/env bash
# Final project - deploy the plain Kubernetes manifests (namespace final-k8s) and verify them.
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
IP=$(minikube ip); export IP

snap 13-images-into-minikube --dir "$P" <<'EOF'
minikube image load ghcr.io/v4xsh/taskboard-backend:1.0.1
minikube image load ghcr.io/v4xsh/taskboard-frontend:1.0.1
minikube image ls | grep taskboard
EOF

snap 14-k8s-manifests-apply --dir "$P" --max-lines 80 <<'EOF'
ls kubernetes/
kubectl apply -f kubernetes/
kubectl rollout status statefulset/taskboard-postgres -n final-k8s --timeout=180s
kubectl rollout status deploy/taskboard-backend -n final-k8s --timeout=240s
kubectl rollout status deploy/taskboard-frontend -n final-k8s --timeout=120s
kubectl get all,cm,secret,pvc,ingress,hpa -n final-k8s
EOF

sleep 60
snap 15-k8s-manifests-verify --dir "$P" <<'EOF'
kubectl logs -n final-k8s deploy/taskboard-backend -c migrate | tail -n 3
kubectl get pods -n final-k8s -o custom-columns=POD:.metadata.name,READY:.status.containerStatuses[0].ready,USER:.spec.securityContext.runAsUser,NODE:.spec.nodeName
kubectl get endpointslices -n final-k8s -l kubernetes.io/service-name=taskboard-backend -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
curl -s -H 'Host: taskboard-k8s.local' http://$IP/api/info; echo
curl -s -H 'Host: taskboard-k8s.local' -X POST http://$IP/api/tasks -H 'Content-Type: application/json' -d '{"title":"Deployed with plain manifests","priority":"LOW"}'; echo
curl -s -o /dev/null -w 'GET / via ingress -> HTTP %{http_code}\n' -H 'Host: taskboard-k8s.local' http://$IP/
kubectl get hpa -n final-k8s
kubectl get pvc -n final-k8s -o custom-columns=PVC:.metadata.name,STATUS:.status.phase,SIZE:.status.capacity.storage,CLASS:.spec.storageClassName
EOF

# plain-manifest copy is only a demo; free its resources (the Helm release in final-app is the real deployment)
kubectl delete namespace final-k8s --wait=false
