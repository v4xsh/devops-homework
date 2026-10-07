#!/usr/bin/env bash
# Session 14 mini project: Deploy -> Observe -> Break -> Investigate -> Root cause -> Fix -> Verify
D=~/devops-homework/session-14-kubernetes-troubleshooting/mini-project
cd $D

snap 01-deploy --dir $D <<'EOF'
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl rollout status deployment/troubleshooting-app -n s14-mini --timeout=120s
kubectl get pods -n s14-mini
kubectl get service -n s14-mini
EOF

snap 02-check-application --dir $D --max-lines 90 <<'EOF'
kubectl get pods -n s14-mini -o wide
POD=$(kubectl get pods -n s14-mini -l app=troubleshooting-app -o jsonpath='{.items[0].metadata.name}'); echo $POD
kubectl describe pod $POD -n s14-mini | sed -n '1,/Conditions:/p'
kubectl describe pod $POD -n s14-mini | sed -n '/Events:/,$p'
kubectl logs $POD -n s14-mini --tail=5
kubectl exec $POD -n s14-mini -- curl -s localhost | head -n 5
EOF

snap 03-check-service-endpoints --dir $D <<'EOF'
kubectl get service -n s14-mini
kubectl describe service troubleshooting-service -n s14-mini
kubectl get endpoints troubleshooting-service -n s14-mini
kubectl get pods -n s14-mini -o custom-columns=POD:.metadata.name,IP:.status.podIP
EOF

snap 04-dns-check --dir $D <<'EOF'
kubectl apply -f dns-test-pod.yaml
kubectl wait --for=condition=Ready pod/dns-test -n s14-mini --timeout=60s
kubectl exec dns-test -n s14-mini -- nslookup troubleshooting-service
kubectl exec dns-test -n s14-mini -- nslookup troubleshooting-service.s14-mini.svc.cluster.local
kubectl exec dns-test -n s14-mini -- wget -qO- -T 3 http://troubleshooting-service | grep '<title>'
EOF

snap 05-broken-pod-get --dir $D <<'EOF'
kubectl apply -f broken-pod.yaml
sleep 5
kubectl get pod project-broken-pod -n s14-mini
sleep 30
kubectl get pod project-broken-pod -n s14-mini
EOF

snap 06-broken-pod-describe --dir $D --max-lines 80 <<'EOF'
kubectl describe pod project-broken-pod -n s14-mini
EOF

snap 07-broken-pod-events-logs --dir $D <<'EOF'
kubectl events -n s14-mini --for pod/project-broken-pod
kubectl logs project-broken-pod -n s14-mini
kubectl get pod project-broken-pod -n s14-mini -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}: {.status.containerStatuses[0].state.waiting.message}{"\n"}'
EOF

snap 08-broken-pod-fix --dir $D <<'EOF'
kubectl delete pod project-broken-pod -n s14-mini
kubectl apply -f fixed-pod.yaml
kubectl wait --for=condition=Ready pod/project-broken-pod -n s14-mini --timeout=90s
kubectl get pod project-broken-pod -n s14-mini
kubectl events -n s14-mini --for pod/project-broken-pod
EOF

snap 09-service-selector-broken --dir $D <<'EOF'
kubectl apply -f service-broken-selector.yaml
sleep 3
kubectl get service -n s14-mini
kubectl get endpoints troubleshooting-service -n s14-mini
kubectl exec dns-test -n s14-mini -- wget -qO- -T 3 http://troubleshooting-service
EOF

snap 10-service-root-cause --dir $D <<'EOF'
kubectl get pods -n s14-mini --show-labels
kubectl describe service troubleshooting-service -n s14-mini
kubectl get pods -n s14-mini -l app=wrong-app
kubectl get pods -n s14-mini -l app=troubleshooting-app
EOF

snap 11-service-fixed --dir $D <<'EOF'
kubectl apply -f service.yaml
sleep 3
kubectl describe service troubleshooting-service -n s14-mini | grep -E 'Selector|Endpoints'
kubectl get endpoints troubleshooting-service -n s14-mini
kubectl exec dns-test -n s14-mini -- wget -qO- -T 3 http://troubleshooting-service | grep '<title>'
EOF

snap 12-final-checklist --dir $D <<'EOF'
kubectl get pods -n s14-mini -o wide
kubectl get svc,endpoints -n s14-mini
kubectl get events -n s14-mini --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 5
EOF
echo MINI14-DONE
