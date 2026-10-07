#!/usr/bin/env bash
# Session 13 mini project: PVC + HPA + probes in namespace s13-mini.
D=~/devops-homework/session-13-storage-hpa-probes/mini-project
cd $D

snap 01-namespace-pvc --dir $D <<'EOF'
kubectl apply -f namespace.yaml
kubectl apply -f pvc.yaml
sleep 4
kubectl get pvc -n s13-mini
kubectl get pv | grep -E 'NAME|s13-mini'
EOF

snap 02-deploy-app-service --dir $D <<'EOF'
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl rollout status deployment/web-app -n s13-mini --timeout=120s
kubectl get pods -n s13-mini -o wide
kubectl get svc,endpoints -n s13-mini
EOF

snap 03-probes-and-resources --dir $D <<'EOF'
POD=$(kubectl get pods -n s13-mini -l app=web-app -o jsonpath='{.items[0].metadata.name}'); echo $POD
kubectl describe pod $POD -n s13-mini | grep -E 'Limits|Requests|cpu:|memory:|Liveness|Readiness|Startup|/data from|ClaimName'
kubectl get pod $POD -n s13-mini -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
EOF

snap 04-hpa --dir $D <<'EOF'
kubectl apply -f hpa.yaml
sleep 60
kubectl get hpa -n s13-mini
kubectl top pods -n s13-mini
EOF

snap 05-task1-storage-persistence --dir $D <<'EOF'
POD_NAME=$(kubectl get pods -n s13-mini -l app=web-app -o jsonpath='{.items[0].metadata.name}'); echo "POD_NAME=$POD_NAME"
kubectl exec -n s13-mini "$POD_NAME" -- sh -c 'echo "Student: Vansh Dobhal (Roll No. 10099)" > /data/student.txt'
kubectl exec -n s13-mini "$POD_NAME" -- cat /data/student.txt
kubectl delete pod -n s13-mini "$POD_NAME"
kubectl rollout status deployment/web-app -n s13-mini --timeout=120s
kubectl get pods -n s13-mini
NEW_POD=$(kubectl get pods -n s13-mini -l app=web-app --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}'); echo "NEW_POD=$NEW_POD"
kubectl exec -n s13-mini "$NEW_POD" -- cat /data/student.txt
EOF

snap 06-task2-service --dir $D <<'EOF'
kubectl port-forward -n s13-mini svc/web-service 8080:80 > /tmp/s13-pf.log 2>&1 & PF=$!; sleep 3
curl -s http://localhost:8080 | head -n 8
cat /tmp/s13-pf.log
kill $PF
EOF

snap 07-task3-start-load --dir $D <<'EOF'
kubectl run load-generator -n s13-mini --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://web-service > /dev/null; done"
kubectl wait --for=condition=Ready pod/load-generator -n s13-mini --timeout=60s
sleep 60
kubectl get hpa -n s13-mini
kubectl top pods -n s13-mini
EOF

snap 08-task3-more-load --dir $D <<'EOF'
kubectl apply -f load-generator.yaml
kubectl rollout status deployment/extra-load -n s13-mini --timeout=90s
sleep 45
kubectl get hpa -n s13-mini
kubectl top pods -n s13-mini
kubectl get pods -n s13-mini -l app=web-app
EOF

for i in 1 2 3; do
snap 09-task3-scale-out-t$i --dir $D <<'EOF'
sleep 45
date '+%H:%M:%S'
kubectl get hpa -n s13-mini
kubectl top pods -n s13-mini -l app=web-app
kubectl get pods -n s13-mini -l app=web-app
EOF
done

snap 10-task3-describe-hpa --dir $D --max-lines 80 <<'EOF'
kubectl describe hpa web-app-hpa -n s13-mini
EOF

snap 11-task3-stop-load --dir $D <<'EOF'
kubectl delete pod load-generator -n s13-mini
kubectl delete -f load-generator.yaml
date '+%H:%M:%S'
kubectl get hpa -n s13-mini
EOF

for i in 1 2 3 4 5 6 7; do
snap 12-task3-scale-down-t$i --dir $D <<'EOF'
sleep 55
date '+%H:%M:%S'
kubectl get hpa -n s13-mini
kubectl get pods -n s13-mini -l app=web-app
EOF
done

snap 13-task3-describe-after-scale-down --dir $D --max-lines 80 <<'EOF'
kubectl describe hpa web-app-hpa -n s13-mini | sed -n '/Metrics:/,$p'
EOF

snap 14-bonus2-readiness-gating --dir $D <<'EOF'
kubectl patch deployment web-app -n s13-mini --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/does-not-exist"}]'
sleep 40
kubectl get pods -n s13-mini -l app=web-app
kubectl get endpoints -n s13-mini web-service
POD=$(kubectl get pods -n s13-mini -l app=web-app -o jsonpath='{.items[0].metadata.name}'); kubectl events -n s13-mini --for pod/$POD | tail -n 3
EOF

snap 15-bonus3-liveness-restart-loop --dir $D <<'EOF'
kubectl apply -f deployment.yaml
kubectl rollout status deployment/web-app -n s13-mini --timeout=120s
kubectl get endpoints -n s13-mini web-service
kubectl patch deployment web-app -n s13-mini --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/path","value":"/crash"}]'
sleep 75
kubectl get pods -n s13-mini -l app=web-app
POD=$(kubectl get pods -n s13-mini -l app=web-app -o jsonpath='{.items[0].metadata.name}'); kubectl events -n s13-mini --for pod/$POD | grep -E 'Unhealthy|Killing' | tail -n 4
EOF

snap 16-restore-final-state --dir $D <<'EOF'
kubectl apply -f deployment.yaml
kubectl rollout status deployment/web-app -n s13-mini --timeout=120s
kubectl get all,pvc -n s13-mini
NEW_POD=$(kubectl get pods -n s13-mini -l app=web-app -o jsonpath='{.items[0].metadata.name}'); kubectl exec -n s13-mini $NEW_POD -- cat /data/student.txt
EOF
echo MINI-DONE
