#!/usr/bin/env bash
# Session 11 / Task 3 - FQDN & service DNS, real lookups within and across namespaces
set -u
D=~/devops-homework/session-11-kubernetes-networking-services/fqdn
cd $D

snap 01-same-namespace-lookups --dir $D <<'EOF'
kubectl get svc -n s11
kubectl exec -n s11 dnsutils -- nslookup web-service-clusterip
kubectl exec -n s11 dnsutils -- nslookup web-service-clusterip.s11
kubectl exec -n s11 dnsutils -- nslookup web-service-clusterip.s11.svc
kubectl exec -n s11 dnsutils -- nslookup web-service-clusterip.s11.svc.cluster.local.
EOF

snap 02-cross-namespace-lookups --dir $D <<'EOF'
kubectl apply -f cross-namespace-client.yaml
kubectl wait --for=condition=Ready pod/dnsutils-s12 pod/curl-s12 -n s12 --timeout=120s
echo "--- from namespace s12: the short name only searches s12, so it FAILS"
kubectl exec -n s12 dnsutils-s12 -- nslookup web-service-clusterip
echo "--- adding the namespace (or the full FQDN) works"
kubectl exec -n s12 dnsutils-s12 -- nslookup web-service-clusterip.s11
kubectl exec -n s12 dnsutils-s12 -- nslookup web-service-clusterip.s11.svc.cluster.local
EOF

snap 03-cross-namespace-curl --dir $D <<'EOF'
kubectl exec -n s12 curl-s12 -- curl -s -m 5 http://web-service-clusterip:8080 || echo "curl exit code $? (could not resolve host)"
kubectl exec -n s12 curl-s12 -- curl -s http://web-service-clusterip.s11:8080
kubectl exec -n s12 curl-s12 -- curl -s http://web-service-clusterip.s11.svc.cluster.local:8080
kubectl exec -n s12 curl-s12 -- curl -s http://web-0.web-service-headless.s11.svc.cluster.local
kubectl exec -n s12 curl-s12 -- curl -sk -o /dev/null -w "kubernetes API via FQDN -> HTTP %{http_code}\n" https://kubernetes.default.svc.cluster.local/version
EOF

snap 04-resolv-conf-per-namespace --dir $D <<'EOF'
kubectl exec -n s11 dnsutils -- cat /etc/resolv.conf
kubectl exec -n s12 dnsutils-s12 -- cat /etc/resolv.conf
EOF

snap 05-pod-a-records-and-srv --dir $D <<'EOF'
POD_IP=$(kubectl get pod curl-client -n s11 -o jsonpath='{.status.podIP}'); echo "curl-client pod IP = $POD_IP"
DASHED=$(echo $POD_IP | tr . -); echo "pod A record name  = $DASHED.s11.pod.cluster.local"
kubectl exec -n s12 dnsutils-s12 -- dig +short $DASHED.s11.pod.cluster.local
echo "--- SRV record: _<port-name>._<protocol>.<svc>.<ns>.svc.cluster.local"
kubectl exec -n s12 dnsutils-s12 -- dig +noall +answer SRV _http._tcp.web-service-clusterip.s11.svc.cluster.local
kubectl exec -n s12 dnsutils-s12 -- dig +noall +answer SRV _web._tcp.web-service-headless.s11.svc.cluster.local
echo "--- reverse (PTR) lookup of the ClusterIP"
kubectl exec -n s12 dnsutils-s12 -- dig +short -x $(kubectl get svc web-service-clusterip -n s11 -o jsonpath='{.spec.clusterIP}')
EOF

snap 06-ndots-search-path-in-action --dir $D <<'EOF'
echo "--- +search makes dig use the resolv.conf search list like an application would"
kubectl exec -n s12 dnsutils-s12 -- dig +search +noall +answer +question web-service-clusterip.s11
echo "--- an external name (fewer than 5 dots) is first tried with every search suffix, then as-is"
kubectl exec -n s12 dnsutils-s12 -- nslookup -debug example.com 2>&1 | grep -E "QUESTIONS|example.com" | head -14
EOF
