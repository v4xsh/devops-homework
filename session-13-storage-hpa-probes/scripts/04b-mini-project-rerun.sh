#!/usr/bin/env bash
# Session 13 mini project - second pass:
#  * Task 2 again on a free local port (8080 on this machine was already taken by another program,
#    so the first port-forward attempt failed - see outputs/06-task2-service.txt)
#  * Task 3 again, this time watching long enough (> 5 min default stabilization window) to see the
#    HPA actually scale back down to minReplicas=2.
D=~/devops-homework/session-13-storage-hpa-probes/mini-project
cd $D

snap 06b-task2-service-port-18013 --dir $D <<'EOF'
ss -ltn | grep -E ':8080 ' | head -n 2
kubectl port-forward -n s13-mini svc/web-service 18013:80 > /tmp/s13-pf.log 2>&1 & PF=$!; sleep 3
curl -s http://localhost:18013 | head -n 8
cat /tmp/s13-pf.log
kill $PF
EOF

snap 17-rerun-load --dir $D <<'EOF'
kubectl get hpa -n s13-mini
kubectl run load-generator -n s13-mini --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://web-service > /dev/null; done"
kubectl apply -f load-generator.yaml
sleep 150
date '+%H:%M:%S'
kubectl get hpa -n s13-mini
kubectl get pods -n s13-mini -l app=web-app
EOF

snap 18-rerun-stop-load --dir $D <<'EOF'
kubectl delete pod load-generator -n s13-mini
kubectl delete -f load-generator.yaml
date '+%H:%M:%S'
kubectl get hpa -n s13-mini
EOF

for i in 1 2 3 4 5 6 7 8 9; do
snap 19-rerun-scale-down-t$i --dir $D <<'EOF'
sleep 60
date '+%H:%M:%S'
kubectl get hpa -n s13-mini
kubectl get pods -n s13-mini -l app=web-app
EOF
done

snap 20-rerun-describe-hpa --dir $D --max-lines 80 <<'EOF'
kubectl describe hpa web-app-hpa -n s13-mini | sed -n '/Metrics:/,$p'
kubectl get events -n s13-mini --field-selector reason=SuccessfulRescale --sort-by=.lastTimestamp
EOF
echo RERUN-DONE
