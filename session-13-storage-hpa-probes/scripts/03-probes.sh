#!/usr/bin/env bash
# Probes demos (liveness / readiness / startup) with real describe + events output.
D=~/devops-homework/session-13-storage-hpa-probes/03-probes
cd $D
kubectl create namespace s13 --dry-run=client -o yaml | kubectl apply -f - >/dev/null

snap 01-liveness-exec-restart --dir $D --max-lines 80 <<'EOF'
kubectl apply -f 01-liveness-exec.yaml
kubectl wait --for=condition=Ready pod/liveness-exec -n s13 --timeout=60s
kubectl get pod liveness-exec -n s13
sleep 60
kubectl get pod liveness-exec -n s13
kubectl describe pod liveness-exec -n s13 | sed -n '/State:/,/Liveness:/p'
kubectl events -n s13 --for pod/liveness-exec
EOF

snap 02-liveness-http-healthy --dir $D <<'EOF'
kubectl apply -f 02-liveness-http.yaml
kubectl wait --for=condition=Ready pod/liveness-demo -n s13 --timeout=60s
sleep 20
kubectl get pod liveness-demo -n s13
kubectl describe pod liveness-demo -n s13 | grep -E 'Liveness|Restart Count'
kubectl logs liveness-demo -n s13 --tail=3
EOF

snap 03-readiness-not-ready --dir $D <<'EOF'
kubectl apply -f 03-readiness.yaml
sleep 20
kubectl get pod readiness-demo -n s13
kubectl get endpoints readiness-demo -n s13
kubectl describe pod readiness-demo -n s13 | grep -E 'Readiness|Ready:|ContainersReady'
kubectl events -n s13 --for pod/readiness-demo | tail -n 3
EOF

snap 04-readiness-becomes-ready --dir $D <<'EOF'
kubectl exec readiness-demo -n s13 -- sh -c 'echo ok > /usr/share/nginx/html/ready.html'
sleep 8
kubectl get pod readiness-demo -n s13 -o wide
kubectl get endpoints readiness-demo -n s13
kubectl exec readiness-demo -n s13 -- rm /usr/share/nginx/html/ready.html
sleep 8
kubectl get pod readiness-demo -n s13
kubectl get endpoints readiness-demo -n s13
kubectl get pod readiness-demo -n s13 -o jsonpath='restartCount={.status.containerStatuses[0].restartCount}{"\n"}'
EOF

snap 05-startup-slow-app-ok --dir $D --max-lines 80 <<'EOF'
kubectl apply -f 04-startup.yaml
sleep 10
kubectl get pod startup-demo -n s13
kubectl wait --for=condition=Ready pod/startup-demo -n s13 --timeout=90s
kubectl get pod startup-demo -n s13
kubectl describe pod startup-demo -n s13 | grep -E 'Startup|Liveness|Readiness|Restart Count'
kubectl events -n s13 --for pod/startup-demo
kubectl logs startup-demo -n s13 --tail=3
EOF

snap 06-startup-budget-too-short --dir $D <<'EOF'
kubectl apply -f 05-startup-too-short.yaml
sleep 50
kubectl get pod startup-too-short -n s13
kubectl events -n s13 --for pod/startup-too-short
kubectl logs startup-too-short -n s13 --previous
EOF

kubectl delete -f 01-liveness-exec.yaml -f 02-liveness-http.yaml -f 03-readiness.yaml -f 04-startup.yaml -f 05-startup-too-short.yaml --wait=false >/dev/null
echo PROBES-DONE
