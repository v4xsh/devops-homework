#!/usr/bin/env bash
# Session 11 / Task 1 - deploy and test all 5 Service types (namespace s11)
set -u
S=~/devops-homework/session-11-kubernetes-networking-services
cd $S

snap 00-namespace-and-clients --dir $S <<'EOF'
kubectl apply -f 00-namespace/namespace.yaml
kubectl apply -f 00-namespace/client-pods.yaml
kubectl wait --for=condition=Ready pod/curl-client pod/dnsutils -n s11 --timeout=120s
kubectl get pods -n s11 -o wide
EOF

snap 01-clusterip-deploy --dir $S <<'EOF'
kubectl apply -f 01-clusterip/
kubectl rollout status deployment/web-app-clusterip -n s11 --timeout=120s
kubectl get deploy,pods -n s11 -l app=web-clusterip -o wide
kubectl get svc web-service-clusterip -n s11 -o wide
kubectl get endpoints web-service-clusterip -n s11
kubectl get endpointslices -n s11 -l kubernetes.io/service-name=web-service-clusterip
EOF

snap 02-clusterip-describe --dir $S <<'EOF'
kubectl describe svc web-service-clusterip -n s11
EOF

snap 03-clusterip-test --dir $S <<'EOF'
CIP=$(kubectl get svc web-service-clusterip -n s11 -o jsonpath='{.spec.clusterIP}'); echo "ClusterIP = $CIP"
kubectl exec -n s11 curl-client -- curl -s http://web-service-clusterip:8080
kubectl exec -n s11 curl-client -- curl -s http://web-service-clusterip.s11.svc.cluster.local:8080
for i in 1 2 3 4 5 6; do kubectl exec -n s11 curl-client -- curl -s http://$CIP:8080; done
echo "--- From OUTSIDE the cluster (WSL host) the ClusterIP is not routable:"
curl -s -m 5 http://$CIP:8080 || echo "curl exit code $? -> ClusterIP is internal-only"
EOF

snap 04-nodeport-deploy --dir $S <<'EOF'
kubectl apply -f 02-nodeport/
kubectl rollout status deployment/web-app-nodeport -n s11 --timeout=120s
kubectl get svc web-service-nodeport -n s11 -o wide
kubectl get endpoints web-service-nodeport -n s11
kubectl describe svc web-service-nodeport -n s11
EOF

snap 05-nodeport-test --dir $S <<'EOF'
minikube ip
echo "--- from the WSL host via <NodeIP>:<nodePort>"
for i in 1 2 3 4; do curl -s http://$(minikube ip):31111; done
echo "--- from inside the cluster via the ClusterIP part of the NodePort service"
kubectl exec -n s11 curl-client -- curl -s http://web-service-nodeport
EOF

snap 06-loadbalancer-pending --dir $S <<'EOF'
kubectl apply -f 03-loadbalancer/
kubectl rollout status deployment/web-app-loadbalancer -n s11 --timeout=120s
echo "--- no minikube tunnel running yet -> no cloud LB -> EXTERNAL-IP stays <pending>"
sleep 5
kubectl get svc web-service-loadbalancer -n s11
kubectl get endpoints web-service-loadbalancer -n s11
EOF

# start the tunnel (acts as the cloud load-balancer controller)
nohup minikube tunnel > /tmp/s11-tunnel.log 2>&1 &
TUNNEL_PID=$!
for i in $(seq 1 30); do
  ip=$(kubectl get svc web-service-loadbalancer -n s11 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -n "$ip" ] && grep -q "Starting tunnel for service web-service-loadbalancer" /tmp/s11-tunnel.log && break; sleep 2
done
sleep 3

snap 07-loadbalancer-tunnel --dir $S <<'EOF'
pgrep -af "minikube tunnel"
cat /tmp/s11-tunnel.log
kubectl get svc web-service-loadbalancer -n s11 -o wide
kubectl describe svc web-service-loadbalancer -n s11
LBIP=$(kubectl get svc web-service-loadbalancer -n s11 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); echo "EXTERNAL-IP = $LBIP"
for i in 1 2 3 4 5; do curl -s -m 5 http://$LBIP:8081; done
EOF

# stop the tunnel gracefully (SIGINT = Ctrl+C) and make sure its ssh port-forward children are gone
kill -INT $TUNNEL_PID 2>/dev/null; sleep 5; pkill -f "minikube tunnel" 2>/dev/null; pkill -f -- "-L 8081:" 2>/dev/null; sleep 2

snap 08-loadbalancer-after-tunnel-stopped --dir $S <<'EOF'
pgrep -af "minikube tunnel" || echo "no minikube tunnel process running"
pgrep -af -- "-L 8081:" || echo "no ssh port-forward for 8081 left"
kubectl get svc web-service-loadbalancer -n s11
curl -s -m 5 http://127.0.0.1:8081 || echo "curl exit code $? -> without the tunnel nothing listens on the external IP"
EOF

snap 09-externalname --dir $S <<'EOF'
kubectl apply -f 04-externalname/service.yaml
kubectl get svc external-docs-service -n s11 -o wide
kubectl describe svc external-docs-service -n s11
kubectl get endpoints external-docs-service -n s11
kubectl exec -n s11 dnsutils -- nslookup external-docs-service.s11.svc.cluster.local
kubectl exec -n s11 dnsutils -- dig +noall +answer external-docs-service.s11.svc.cluster.local
kubectl exec -n s11 curl-client -- curl -s -o /dev/null -w "HTTP %{http_code} from %{remote_ip}\n" -H "Host: example.com" http://external-docs-service
EOF

snap 10-headless-deploy --dir $S <<'EOF'
kubectl apply -f 05-headless/
kubectl rollout status statefulset/web -n s11 --timeout=180s
kubectl get sts,pods -n s11 -l app=web-headless -o wide
kubectl get svc web-service-headless -n s11 -o wide
kubectl get endpoints web-service-headless -n s11
kubectl describe svc web-service-headless -n s11
EOF

snap 11-headless-dns --dir $S <<'EOF'
kubectl get pods -n s11 -l app=web-headless -o custom-columns=NAME:.metadata.name,IP:.status.podIP
kubectl exec -n s11 dnsutils -- nslookup web-service-headless.s11.svc.cluster.local
echo "--- compare: a normal ClusterIP service returns ONE virtual IP"
kubectl exec -n s11 dnsutils -- nslookup web-service-clusterip.s11.svc.cluster.local
echo "--- stable per-pod DNS names from the StatefulSet + headless service"
kubectl exec -n s11 dnsutils -- nslookup web-0.web-service-headless.s11.svc.cluster.local
kubectl exec -n s11 dnsutils -- dig +short web-1.web-service-headless.s11.svc.cluster.local
kubectl exec -n s11 dnsutils -- dig +short web-2.web-service-headless.s11.svc.cluster.local
kubectl exec -n s11 curl-client -- curl -s http://web-0.web-service-headless.s11.svc.cluster.local
kubectl exec -n s11 curl-client -- curl -s http://web-2.web-service-headless
EOF

snap 12-all-services-summary --dir $S <<'EOF'
kubectl get svc -n s11 -o wide
kubectl get endpointslices -n s11
EOF
