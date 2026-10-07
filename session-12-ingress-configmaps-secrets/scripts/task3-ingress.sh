#!/usr/bin/env bash
# Session 12 / Task 3 + 4 - Ingress routing (path + host based) and the ingress-nginx controller
set -u
S=~/devops-homework/session-12-ingress-configmaps-secrets
D=$S/03-ingress
cd $D

snap 11-ingress-backends --dir $S <<'EOF'
kubectl apply -f app1.yaml -f app2.yaml
kubectl rollout status deployment/app1 -n s12 --timeout=120s
kubectl rollout status deployment/app2 -n s12 --timeout=120s
kubectl get deploy,svc -n s12 -l 'app in (app1,app2)'
kubectl get svc app1-service app2-service -n s12
kubectl get endpointslices -n s12
EOF

snap 12-ingress-create --dir $S <<'EOF'
kubectl apply -f ingress-path-based.yaml -f ingress-host-based.yaml
for i in $(seq 1 40); do a=$(kubectl get ingress path-ingress -n s12 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); b=$(kubectl get ingress host-ingress -n s12 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); [ -n "$a" ] && [ -n "$b" ] && break; sleep 3; done
kubectl get ingress -n s12
kubectl describe ingress path-ingress -n s12
EOF

snap 13-ingress-describe-host --dir $S <<'EOF'
kubectl describe ingress host-ingress -n s12
EOF

snap 14-ingress-path-routing --dir $S <<'EOF'
IP=$(minikube ip); echo "minikube ip = $IP"
curl -s -H "Host: app.local" http://$IP/app1
curl -s -H "Host: app.local" http://$IP/app2
curl -s -H "Host: app.local" http://$IP/app1/anything/below
curl -s -H "Host: app.local" http://$IP/app2
echo "--- an unknown path on app.local has no rule -> controller's default backend (404)"
curl -s -o /dev/null -w "GET app.local/other -> HTTP %{http_code}\n" -H "Host: app.local" http://$IP/other
EOF

snap 15-ingress-host-routing --dir $S <<'EOF'
IP=$(minikube ip)
curl -s -H "Host: app1.local" http://$IP/
curl -s -H "Host: app2.local" http://$IP/
echo "--- same IP, same port 80: only the Host header differs"
curl -s -o /dev/null -w "Host: unknown.local -> HTTP %{http_code}\n" -H "Host: unknown.local" http://$IP/
echo "--- using real name resolution instead of -H, via curl --resolve"
curl -s --resolve app1.local:80:$IP http://app1.local/
curl -s --resolve app2.local:80:$IP http://app2.local/
echo "--- load balancing across the 2 replicas behind app1"
for i in 1 2 3 4 5 6; do curl -s -H "Host: app1.local" http://$IP/; done
EOF

snap 16-ingress-controller-logs --dir $S <<'EOF'
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --since=2m | grep -E "s12-app[12]-service" | tail -6
EOF

cd $S/ingress-vs-controller
snap 01-controller-in-cluster --dir $S/ingress-vs-controller --max-lines 80 <<'EOF'
kubectl get all -n ingress-nginx
kubectl get ingressclass -o wide
kubectl describe ingressclass nginx
EOF

snap 02-controller-details --dir $S/ingress-vs-controller --max-lines 80 <<'EOF'
kubectl get deploy ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl get deploy ingress-nginx-controller -n ingress-nginx -o jsonpath='{range .spec.template.spec.containers[0].args[*]}{@}{"\n"}{end}'
kubectl get deploy ingress-nginx-controller -n ingress-nginx -o jsonpath='{range .spec.template.spec.containers[0].ports[*]}{.name} containerPort={.containerPort} hostPort={.hostPort}{"\n"}{end}'
echo "--- the controller turned our Ingress objects into nginx server blocks:"
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- grep -n -E "## start server|server_name \"app" /etc/nginx/nginx.conf
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- sh -c "grep -E 'location ~\* \"\^/app[12]' /etc/nginx/nginx.conf"
EOF

snap 03-ingress-without-controller-class --dir $S/ingress-vs-controller <<'EOF'
echo "--- an Ingress that names a class with NO controller is accepted by the API but nobody implements it"
kubectl create ingress orphan-ingress -n s12 --class=traefik --rule="orphan.local/=app1-service:80"
sleep 15
kubectl get ingress orphan-ingress -n s12
curl -s -o /dev/null -w "Host: orphan.local -> HTTP %{http_code} (no controller programmed this route)\n" -H "Host: orphan.local" http://$(minikube ip)/
kubectl delete ingress orphan-ingress -n s12
EOF
