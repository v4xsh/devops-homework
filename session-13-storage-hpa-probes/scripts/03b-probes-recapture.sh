#!/usr/bin/env bash
# Re-capture of the two probe demos whose containers restart (after adding terminationGracePeriodSeconds: 5).
D=~/devops-homework/session-13-storage-hpa-probes/03-probes
cd $D
kubectl delete pod liveness-exec startup-too-short -n s13 --ignore-not-found --wait=true >/dev/null
kubectl delete events -n s13 --all >/dev/null 2>&1   # clean event history so only the new run is shown
snap 01-liveness-exec-restart --dir $D --max-lines 80 <<'EOF'
kubectl apply -f 01-liveness-exec.yaml
kubectl wait --for=condition=Ready pod/liveness-exec -n s13 --timeout=60s
kubectl get pod liveness-exec -n s13
sleep 60
kubectl get pod liveness-exec -n s13
kubectl describe pod liveness-exec -n s13 | sed -n '/State:/,/Liveness:/p'
kubectl events -n s13 --for pod/liveness-exec
EOF
snap 06-startup-budget-too-short --dir $D <<'EOF'
kubectl apply -f 05-startup-too-short.yaml
sleep 50
kubectl get pod startup-too-short -n s13
kubectl events -n s13 --for pod/startup-too-short
kubectl logs startup-too-short -n s13 --previous
EOF
kubectl delete -f 01-liveness-exec.yaml -f 05-startup-too-short.yaml --wait=false >/dev/null
echo PROBES2-DONE
