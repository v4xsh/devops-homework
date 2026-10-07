#!/usr/bin/env bash
# Session 09 - "Learn Kubernetes Basics" (kubernetes.io) modules 1-6, run in namespace s09
set -u
D=~/devops-homework/session-09-kubernetes-fundamentals
cd "$D"
kubectl delete ns s09 --ignore-not-found --wait=true >/dev/null 2>&1

# Module 1 - Create a cluster
snap 10-module1-create-cluster --dir "$D" <<'EOF'
minikube status
kubectl cluster-info
kubectl get nodes
kubectl create namespace s09
kubectl get ns s09
EOF

# Module 2 - Deploy an app
snap 11-module2-deploy-app --dir "$D" <<'EOF'
kubectl create deployment kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1 -n s09
kubectl annotate deployment/kubernetes-bootcamp -n s09 kubernetes.io/change-cause='initial deploy kubernetes-bootcamp:v1'
kubectl rollout status deployment/kubernetes-bootcamp -n s09 --timeout=120s
kubectl get deployments -n s09
kubectl get deployment kubernetes-bootcamp -n s09 -o yaml | sed -n '/^spec:/,/^status:/p' | head -n 30
EOF

# Module 3 - Explore the app: get / describe / logs / exec + kubectl proxy
snap 12-module3-explore-get-describe --dir "$D" --max-lines 80 <<'EOF'
kubectl get pods -n s09 -o wide
export POD_NAME=$(kubectl get pods -n s09 -l app=kubernetes-bootcamp -o jsonpath='{.items[0].metadata.name}'); echo "POD_NAME=$POD_NAME"
kubectl describe pod $POD_NAME -n s09 | sed -n '1,/^Conditions:/p'
kubectl describe pod $POD_NAME -n s09 | sed -n '/^Events:/,$p'
EOF

snap 13-module3-explore-logs-exec --dir "$D" <<'EOF'
export POD_NAME=$(kubectl get pods -n s09 -l app=kubernetes-bootcamp -o jsonpath='{.items[0].metadata.name}')
kubectl proxy --port=8099 >/tmp/s09-proxy.log 2>&1 & sleep 2
curl -s http://localhost:8099/version | head -n 5
curl -s http://localhost:8099/api/v1/namespaces/s09/pods/$POD_NAME:8080/proxy/
kubectl logs $POD_NAME -n s09
kubectl exec $POD_NAME -n s09 -- env | grep -E 'HOSTNAME|KUBERNETES_SERVICE|NPM_CONFIG|NODE_VERSION'
kubectl exec $POD_NAME -n s09 -- sh -c 'ls /; head -n 12 server.js'
kubectl exec $POD_NAME -n s09 -- curl -s http://localhost:8080
pkill -f 'kubectl proxy --port=8099'; echo "proxy stopped"
EOF

# Module 4 - Expose the app with a Service + labels
snap 14-module4-expose-service --dir "$D" --max-lines 80 <<'EOF'
kubectl get services -n s09
kubectl expose deployment/kubernetes-bootcamp --type="NodePort" --port 8080 -n s09
kubectl get services -n s09
kubectl describe services/kubernetes-bootcamp -n s09
export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -n s09 -o go-template='{{(index .spec.ports 0).nodePort}}'); echo "NODE_PORT=$NODE_PORT"
curl -s http://$(minikube ip):$NODE_PORT
EOF

snap 15-module4-labels --dir "$D" --max-lines 80 <<'EOF'
kubectl describe deployment kubernetes-bootcamp -n s09 | grep -E '^(Labels|Selector)'
kubectl get pods -n s09 -l app=kubernetes-bootcamp
kubectl get services -n s09 -l app=kubernetes-bootcamp
export POD_NAME=$(kubectl get pods -n s09 -l app=kubernetes-bootcamp -o jsonpath='{.items[0].metadata.name}')
kubectl label pods $POD_NAME version=v1 -n s09
kubectl get pods -n s09 --show-labels
kubectl get pods -n s09 -l version=v1
kubectl delete service -l app=kubernetes-bootcamp -n s09
kubectl get services -n s09
export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -n s09 -o go-template='{{(index .spec.ports 0).nodePort}}' 2>/dev/null); curl -s -m 3 http://$(minikube ip):${NODE_PORT:-30000} || echo "curl failed -> service removed, app no longer reachable from outside"
kubectl exec -n s09 $POD_NAME -- curl -s http://localhost:8080
EOF

# Module 5 - Scale the app (re-expose first, as in the tutorial)
snap 16-module5-scale-up --dir "$D" --max-lines 80 <<'EOF'
kubectl expose deployment/kubernetes-bootcamp --type="NodePort" --port 8080 -n s09
kubectl get rs -n s09
kubectl scale deployments/kubernetes-bootcamp --replicas=4 -n s09
kubectl rollout status deployment/kubernetes-bootcamp -n s09 --timeout=120s
kubectl get deployments -n s09
kubectl get pods -n s09 -o wide
kubectl describe deployments/kubernetes-bootcamp -n s09 | sed -n '/^Events:/,$p'
kubectl get endpointslices -n s09 -l kubernetes.io/service-name=kubernetes-bootcamp
EOF

snap 17-module5-load-balancing --dir "$D" <<'EOF'
export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -n s09 -o go-template='{{(index .spec.ports 0).nodePort}}'); echo "NODE_PORT=$NODE_PORT"
for i in $(seq 1 8); do curl -s http://$(minikube ip):$NODE_PORT; done
for i in $(seq 1 40); do curl -s http://$(minikube ip):$NODE_PORT; done | grep -o 'kubernetes-bootcamp-[a-z0-9-]*' | sort | uniq -c
kubectl scale deployments/kubernetes-bootcamp --replicas=2 -n s09
sleep 5; kubectl get deployments -n s09
kubectl get pods -n s09 -o wide
EOF

# Module 6 - Rolling update to v2, a failed update to a bad tag, and rollback
snap 18-module6-rolling-update --dir "$D" --max-lines 80 <<'EOF'
kubectl scale deployments/kubernetes-bootcamp --replicas=4 -n s09 && kubectl rollout status deployment/kubernetes-bootcamp -n s09 --timeout=120s
kubectl get pods -n s09 -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[0].image,BEING-DELETED-AT:.metadata.deletionTimestamp'
kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=docker.io/jocatalin/kubernetes-bootcamp:v2 -n s09
kubectl annotate deployment/kubernetes-bootcamp -n s09 kubernetes.io/change-cause='update image to jocatalin/kubernetes-bootcamp:v2' --overwrite
sleep 2; kubectl get pods -n s09
kubectl rollout status deployments/kubernetes-bootcamp -n s09 --timeout=120s
kubectl get pods -n s09
kubectl get rs -n s09
export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -n s09 -o go-template='{{(index .spec.ports 0).nodePort}}'); curl -s http://$(minikube ip):$NODE_PORT
kubectl get pods -n s09 -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[0].image,BEING-DELETED-AT:.metadata.deletionTimestamp'
EOF

snap 19-module6-bad-update-rollback --dir "$D" --max-lines 90 <<'EOF'
kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=gcr.io/google-samples/kubernetes-bootcamp:v10 -n s09
kubectl annotate deployment/kubernetes-bootcamp -n s09 kubernetes.io/change-cause='update image to non-existent tag v10' --overwrite
sleep 25; kubectl get deployments -n s09
kubectl get pods -n s09
kubectl describe pods -n s09 -l app=kubernetes-bootcamp | grep -E 'Image:|Reason:|Failed' | sort | uniq -c
kubectl rollout history deployment/kubernetes-bootcamp -n s09
kubectl rollout undo deployments/kubernetes-bootcamp -n s09
kubectl rollout status deployments/kubernetes-bootcamp -n s09 --timeout=120s
kubectl get pods -n s09
kubectl get pods -n s09 -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[0].image,BEING-DELETED-AT:.metadata.deletionTimestamp'
kubectl rollout history deployment/kubernetes-bootcamp -n s09
EOF

snap 20-cleanup --dir "$D" <<'EOF'
kubectl delete service kubernetes-bootcamp -n s09
kubectl delete deployment kubernetes-bootcamp -n s09
kubectl delete namespace s09
kubectl get ns s09 2>&1 || true
EOF
