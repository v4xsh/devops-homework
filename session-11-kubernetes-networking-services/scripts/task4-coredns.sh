#!/usr/bin/env bash
# Session 11 / Task 4 - CoreDNS: components, config and DNS troubleshooting
set -u
D=~/devops-homework/session-11-kubernetes-networking-services/coredns
cd $D

snap 01-coredns-components --dir $D <<'EOF'
kubectl get deploy coredns -n kube-system -o wide
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
kubectl get svc kube-dns -n kube-system -o wide
kubectl get endpointslices -n kube-system -l kubernetes.io/service-name=kube-dns
EOF

snap 02-coredns-configmap --dir $D --max-lines 60 <<'EOF'
kubectl get configmap coredns -n kube-system -o yaml
EOF

snap 03-pod-resolv-conf --dir $D <<'EOF'
kubectl exec -n s11 dnsutils -- cat /etc/resolv.conf
kubectl get pod dnsutils -n s11 -o jsonpath='{.spec.dnsPolicy}{"\n"}'
minikube ssh -- sudo grep -A2 clusterDNS /var/lib/kubelet/config.yaml
EOF

snap 04-resolution-flow --dir $D <<'EOF'
echo "--- cluster zone: answered authoritatively by the kubernetes plugin (aa flag)"
kubectl exec -n s11 dnsutils -- dig web-service-clusterip.s11.svc.cluster.local +noall +comments +answer | grep -E "flags|IN"
echo "--- external zone: not cluster.local, so the forward plugin sends it to the node's resolver"
kubectl exec -n s11 dnsutils -- dig example.com +noall +comments +answer | grep -E "flags|IN"
echo "--- the hosts plugin serves host.minikube.internal"
kubectl exec -n s11 dnsutils -- dig +short host.minikube.internal
echo "--- query a CoreDNS pod directly instead of the kube-dns ClusterIP"
COREDNS_IP=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].status.podIP}'); echo "CoreDNS pod IP: $COREDNS_IP"
kubectl exec -n s11 dnsutils -- dig @$COREDNS_IP +short kube-dns.kube-system.svc.cluster.local
EOF

snap 05-dns-troubleshooting-checklist --dir $D --max-lines 80 <<'EOF'
echo "1) are the CoreDNS pods running and ready?"
kubectl get pods -n kube-system -l k8s-app=kube-dns
echo "2) does the kube-dns service have endpoints?"
kubectl get endpoints kube-dns -n kube-system
echo "3) any errors in the CoreDNS logs?"
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=15
echo "4) can a debug pod resolve the API server service and an external name?"
kubectl exec -n s11 dnsutils -- nslookup kubernetes.default
kubectl exec -n s11 dnsutils -- nslookup example.com
echo "5) is CoreDNS healthy according to its own ready/health endpoints?"
COREDNS_IP=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].status.podIP}')
kubectl exec -n s11 curl-client -- curl -s http://$COREDNS_IP:8181/ready; echo
kubectl exec -n s11 curl-client -- curl -s http://$COREDNS_IP:8080/health; echo
EOF

snap 06-dns-failure-examples --dir $D <<'EOF'
echo "--- typo in service name -> NXDOMAIN"
kubectl exec -n s11 dnsutils -- nslookup web-servce-clusterip.s11.svc.cluster.local
echo "--- wrong namespace -> NXDOMAIN"
kubectl exec -n s11 dnsutils -- nslookup web-service-clusterip.default.svc.cluster.local
echo "--- CoreDNS metrics (prometheus plugin on :9153) count responses by rcode"
COREDNS_IP=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].status.podIP}')
kubectl exec -n s11 curl-client -- curl -s http://$COREDNS_IP:9153/metrics | grep -E "^coredns_dns_responses_total" | head -8
EOF

snap 07-coredns-log-plugin --dir $D <<'XEOF'
echo "--- minikube's Corefile already contains the 'log' plugin, so every query is logged"
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | head -3
kubectl exec -n s11 dnsutils -- nslookup web-service-headless.s11.svc.cluster.local > /dev/null
kubectl exec -n s11 dnsutils -- nslookup does-not-exist.s11.svc.cluster.local > /dev/null 2>&1
kubectl exec -n s11 dnsutils -- dig +short example.com > /dev/null
sleep 2
echo "dnsutils pod IP: $(kubectl get pod dnsutils -n s11 -o jsonpath='{.status.podIP}')"
kubectl logs -n kube-system -l k8s-app=kube-dns --since=30s --tail=-1 | grep "$(kubectl get pod dnsutils -n s11 -o jsonpath='{.status.podIP}'):" | grep -E "web-service-headless|does-not-exist|example.com" | tail -6
XEOF
