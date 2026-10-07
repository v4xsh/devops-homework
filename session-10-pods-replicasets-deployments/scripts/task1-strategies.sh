#!/usr/bin/env bash
# Session 10 - Task 1: deployment strategies (all output captured with snap)
set -u
D=~/devops-homework/session-10-pods-replicasets-deployments
cd "$D"
T=task1-deployment-strategies
for ns in s10-rolling s10-bluegreen s10-canary s10-recreate; do
  kubectl delete ns $ns --ignore-not-found --wait=true >/dev/null 2>&1
  kubectl create ns $ns >/dev/null
  kubectl apply -n $ns -f $T/common/curl-client.yaml >/dev/null
done
for ns in s10-rolling s10-bluegreen s10-canary s10-recreate; do kubectl wait -n $ns --for=condition=Ready pod/curl-client --timeout=120s >/dev/null; done

########## 01 ROLLING UPDATE ##########
snap 01-rolling-v1-deploy --dir "$D" <<'EOF'
kubectl apply -n s10-rolling -f task1-deployment-strategies/01-rolling-update/deployment-v1.yaml -f task1-deployment-strategies/01-rolling-update/service.yaml
kubectl rollout status deployment/app-rolling -n s10-rolling --timeout=120s
kubectl get deploy app-rolling -n s10-rolling -o jsonpath='{.spec.strategy}{"\n"}'
kubectl get pods -n s10-rolling -l app=app-rolling -L version -o wide
kubectl get rs -n s10-rolling
kubectl exec -n s10-rolling curl-client -- curl -s http://app-rolling-service | grep -o 'VERSION: v[12]'
EOF

snap 02-rolling-update-v1-to-v2 --dir "$D" --max-lines 90 <<'EOF'
bash scripts/watch-pods.sh s10-rolling outputs/01-rolling-watch.log & sleep 1
bash scripts/curl-loop.sh s10-rolling http://app-rolling-service 70 0.5 'VERSION: v[12]' > outputs/01-rolling-curl-during-update.log 2>&1 & sleep 1
kubectl apply -n s10-rolling -f task1-deployment-strategies/01-rolling-update/deployment-v2.yaml
sleep 5; echo "--- mid-rollout ---"; kubectl get pods -n s10-rolling -l app=app-rolling -L version
kubectl get rs -n s10-rolling -L version
kubectl rollout status deployment/app-rolling -n s10-rolling --timeout=180s
echo "--- after rollout ---"; kubectl get pods -n s10-rolling -l app=app-rolling -L version
kubectl get rs -n s10-rolling
kubectl rollout history deployment/app-rolling -n s10-rolling
EOF

snap 03-rolling-verify-and-rollback --dir "$D" --max-lines 100 <<'EOF'
sleep 25; pkill -f 'get pods -n s10-rolling -w'; wait 2>/dev/null; echo "watch + curl loop finished"
cat outputs/01-rolling-watch.log | grep -v curl-client
awk '{print $2,$3}' outputs/01-rolling-curl-during-update.log | sort | uniq -c
kubectl describe deployment app-rolling -n s10-rolling | sed -n '/^Events:/,$p'
kubectl rollout undo deployment/app-rolling -n s10-rolling --to-revision=1 && kubectl rollout status deployment/app-rolling -n s10-rolling --timeout=180s
kubectl exec -n s10-rolling curl-client -- curl -s http://app-rolling-service | grep -o 'VERSION: v[12]'
kubectl rollout history deployment/app-rolling -n s10-rolling
EOF

########## 02 BLUE-GREEN ##########
snap 04-bluegreen-deploy --dir "$D" --max-lines 80 <<'EOF'
kubectl apply -n s10-bluegreen -f task1-deployment-strategies/02-blue-green/deployment-blue.yaml -f task1-deployment-strategies/02-blue-green/deployment-green.yaml -f task1-deployment-strategies/02-blue-green/service-blue.yaml
kubectl rollout status deployment/app-blue -n s10-bluegreen --timeout=120s && kubectl rollout status deployment/app-green -n s10-bluegreen --timeout=120s
kubectl get deploy,svc -n s10-bluegreen -o wide
kubectl get pods -n s10-bluegreen -l app=myapp -L slot,version -o wide
kubectl get endpointslices -n s10-bluegreen -l kubernetes.io/service-name=myapp-service
EOF

snap 05-bluegreen-switch --dir "$D" --max-lines 90 <<'EOF'
kubectl get svc myapp-service -n s10-bluegreen -o jsonpath='selector BEFORE: {.spec.selector}{"\n"}'
kubectl exec -n s10-bluegreen curl-client -- sh -c 'for i in $(seq 1 10); do curl -s http://myapp-service | grep -oE "(BLUE|GREEN) ENVIRONMENT"; done' | sort | uniq -c
kubectl patch service myapp-service -n s10-bluegreen -p '{"spec":{"selector":{"app":"myapp","slot":"green"}}}'
kubectl get svc myapp-service -n s10-bluegreen -o jsonpath='selector AFTER:  {.spec.selector}{"\n"}'
sleep 2; kubectl exec -n s10-bluegreen curl-client -- sh -c 'for i in $(seq 1 10); do curl -s http://myapp-service | grep -oE "(BLUE|GREEN) ENVIRONMENT"; done' | sort | uniq -c
kubectl get endpointslices -n s10-bluegreen -l kubernetes.io/service-name=myapp-service
kubectl get pods -n s10-bluegreen -l slot=green -o custom-columns=POD:.metadata.name,IP:.status.podIP,SLOT:.metadata.labels.slot
EOF

snap 06-bluegreen-rollback-and-cleanup --dir "$D" <<'EOF'
kubectl apply -n s10-bluegreen -f task1-deployment-strategies/02-blue-green/service-blue.yaml
sleep 2; kubectl exec -n s10-bluegreen curl-client -- sh -c 'for i in $(seq 1 5); do curl -s http://myapp-service | grep -oE "(BLUE|GREEN) ENVIRONMENT"; done' | sort | uniq -c
kubectl apply -n s10-bluegreen -f task1-deployment-strategies/02-blue-green/service-green.yaml
sleep 2; kubectl exec -n s10-bluegreen curl-client -- sh -c 'for i in $(seq 1 5); do curl -s http://myapp-service | grep -oE "(BLUE|GREEN) ENVIRONMENT"; done' | sort | uniq -c
kubectl scale deployment app-blue -n s10-bluegreen --replicas=0
kubectl get deploy -n s10-bluegreen
EOF

########## 03 CANARY ##########
snap 07-canary-deploy --dir "$D" --max-lines 80 <<'EOF'
kubectl apply -n s10-canary -f task1-deployment-strategies/03-canary/
kubectl rollout status deployment/app-stable -n s10-canary --timeout=180s && kubectl rollout status deployment/app-canary -n s10-canary --timeout=120s
kubectl get deploy,svc -n s10-canary
kubectl get pods -n s10-canary -l app=myapp-canary -L track,version
kubectl describe svc myapp-canary-service -n s10-canary | grep -E 'Selector|Endpoints'
kubectl get endpointslices -n s10-canary -l kubernetes.io/service-name=myapp-canary-service -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" "}{.targetRef.name}{"\n"}{end}' | sort -k2
EOF

snap 08-canary-traffic-split --dir "$D" <<'EOF'
for run in 1 2 3; do echo "== run $run: 100 requests =="; kubectl exec -n s10-canary curl-client -- sh -c 'for i in $(seq 1 100); do curl -s http://myapp-canary-service | grep -oE "STABLE v1|CANARY v2"; done' | sort | uniq -c; done
echo "== 300 requests total =="; kubectl exec -n s10-canary curl-client -- sh -c 'for i in $(seq 1 300); do curl -s http://myapp-canary-service | grep -oE "STABLE v1|CANARY v2"; done' | sort | uniq -c
EOF

snap 09-canary-promote-50-percent --dir "$D" <<'EOF'
kubectl scale deployment app-canary -n s10-canary --replicas=5 && kubectl scale deployment app-stable -n s10-canary --replicas=5
kubectl rollout status deployment/app-canary -n s10-canary --timeout=120s
sleep 8; kubectl get deploy -n s10-canary
kubectl exec -n s10-canary curl-client -- sh -c 'for i in $(seq 1 200); do curl -s http://myapp-canary-service | grep -oE "STABLE v1|CANARY v2"; done' | sort | uniq -c
EOF

########## 04 RECREATE ##########
snap 10-recreate-v1-deploy --dir "$D" <<'EOF'
kubectl apply -n s10-recreate -f task1-deployment-strategies/04-recreate/deployment-v1.yaml -f task1-deployment-strategies/04-recreate/service.yaml
kubectl rollout status deployment/app-recreate -n s10-recreate --timeout=120s
kubectl get deploy app-recreate -n s10-recreate -o jsonpath='{.spec.strategy}{"\n"}'
kubectl get pods -n s10-recreate -l app=app-recreate -L version
kubectl exec -n s10-recreate curl-client -- curl -s http://app-recreate-service | grep -o 'VERSION: v[12]'
EOF

snap 11-recreate-update --dir "$D" --max-lines 90 <<'EOF'
bash scripts/watch-pods.sh s10-recreate outputs/04-recreate-watch.log & sleep 1
bash scripts/curl-loop.sh s10-recreate http://app-recreate-service 30 0.5 'VERSION: v[12]' > outputs/04-recreate-curl-during-update.log 2>&1 & sleep 2
kubectl apply -n s10-recreate -f task1-deployment-strategies/04-recreate/deployment-v2.yaml
sleep 1; kubectl get pods -n s10-recreate -l app=app-recreate -L version
kubectl get rs -n s10-recreate -L version
kubectl rollout status deployment/app-recreate -n s10-recreate --timeout=120s
kubectl get pods -n s10-recreate -l app=app-recreate -L version
EOF

snap 12-recreate-watch-log --dir "$D" --max-lines 100 <<'EOF'
sleep 20; pkill -f 'get pods -n s10-recreate -w'; wait 2>/dev/null; echo "watch + curl loop finished"
grep -v curl-client outputs/04-recreate-watch.log
cat outputs/04-recreate-curl-during-update.log | uniq -c -f1
kubectl describe deployment app-recreate -n s10-recreate | sed -n '/^StrategyType/p;/^Events:/,$p'
kubectl rollout history deployment/app-recreate -n s10-recreate
EOF
