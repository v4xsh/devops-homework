#!/usr/bin/env bash
# Task 2: break -> investigate -> fix -> verify, for every scenario.
# Usage: bash 02-troubleshooting.sh [01 02 ... 10]   (no args = all scenarios)
# Each scenario folder gets screenshots/ + outputs/ with a "before" and "after" capture.
B=~/devops-homework/session-14-kubernetes-troubleshooting/02-troubleshooting
kubectl create namespace s14 --dry-run=client -o yaml | kubectl apply -f - >/dev/null

########## 01 CrashLoopBackOff ##########
s01() {
D=$B/01-crashloopbackoff; cd $D
kubectl delete events -n s14 --all >/dev/null 2>&1   # start with a clean event history for this demo
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
kubectl wait --for=jsonpath='{.status.containerStatuses[0].state.waiting.reason}'=CrashLoopBackOff pod/crashloop-app -n s14 --timeout=120s
kubectl get pod crashloop-app -n s14
kubectl describe pod crashloop-app -n s14 | sed -n '/State:/,/Restart Count/p'
kubectl logs crashloop-app -n s14
kubectl logs crashloop-app -n s14 --previous
kubectl events -n s14 --for pod/crashloop-app
kubectl get pod crashloop-app -n s14 -o jsonpath='{.spec.containers[0].env}{"\n"}'
EOF
snap after --dir $D <<'EOF'
kubectl delete pod crashloop-app -n s14 --wait=true
kubectl apply -f fixed.yaml
kubectl wait --for=condition=Ready pod/crashloop-app -n s14 --timeout=90s
sleep 12
kubectl get pod crashloop-app -n s14
kubectl logs crashloop-app -n s14
kubectl exec crashloop-app -n s14 -- printenv DATABASE_URL
EOF
kubectl delete -f fixed.yaml --wait=false >/dev/null
}

########## 02 ImagePullBackOff ##########
s02() {
D=$B/02-imagepullbackoff; cd $D
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
sleep 40
kubectl get pod imagepull-app -n s14
kubectl describe pod imagepull-app -n s14 | sed -n '/Containers:/,/Ready:/p'
kubectl describe pod imagepull-app -n s14 | sed -n '/Events:/,$p'
kubectl get pod imagepull-app -n s14 -o jsonpath='{.status.containerStatuses[0].state.waiting}{"\n"}'
EOF
snap after --dir $D <<'EOF'
kubectl delete pod imagepull-app -n s14 --wait=true
kubectl apply -f fixed.yaml
kubectl wait --for=condition=Ready pod/imagepull-app -n s14 --timeout=90s
kubectl get pod imagepull-app -n s14 -o wide
kubectl get pod imagepull-app -n s14 -o jsonpath='{.spec.containers[0].image}{"  ->  "}{.status.containerStatuses[0].imageID}{"\n"}'
kubectl events -n s14 --for pod/imagepull-app
EOF
kubectl delete -f fixed.yaml --wait=false >/dev/null
}

########## 03 ErrImagePull ##########
s03() {
D=$B/03-errimagepull; cd $D
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
sleep 6
kubectl get pod errimagepull-app -n s14
kubectl describe pod errimagepull-app -n s14 | sed -n '/Events:/,$p'
sleep 30
kubectl get pod errimagepull-app -n s14
docker exec minikube nslookup dockerr.io 2>&1 | tail -n 3
docker exec minikube nslookup registry-1.docker.io 2>&1 | tail -n 4
EOF
snap after --dir $D <<'EOF'
kubectl delete pod errimagepull-app -n s14 --wait=true
kubectl apply -f fixed.yaml
kubectl wait --for=condition=Ready pod/errimagepull-app -n s14 --timeout=90s
kubectl get pod errimagepull-app -n s14
kubectl events -n s14 --for pod/errimagepull-app
EOF
kubectl delete -f fixed.yaml --wait=false >/dev/null
}

########## 04 Pending ##########
s04() {
D=$B/04-pending; cd $D
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
sleep 8
kubectl get pod pending-app -n s14 -o wide
kubectl describe pod pending-app -n s14 | sed -n '/Requests:/,/Environment/p'
kubectl describe pod pending-app -n s14 | sed -n '/Events:/,$p'
kubectl get node minikube -o jsonpath='allocatable cpu={.status.allocatable.cpu} memory={.status.allocatable.memory}{"\n"}'
kubectl describe node minikube | sed -n '/Allocated resources/,/Events/p'
EOF
snap after --dir $D <<'EOF'
kubectl delete pod pending-app -n s14 --wait=true
kubectl apply -f fixed.yaml
kubectl wait --for=condition=Ready pod/pending-app -n s14 --timeout=90s
kubectl get pod pending-app -n s14 -o wide
kubectl events -n s14 --for pod/pending-app
EOF
kubectl delete -f fixed.yaml --wait=false >/dev/null
}

########## 05 ContainerCreating ##########
s05() {
D=$B/05-containercreating; cd $D
kubectl delete events -n s14 --all >/dev/null 2>&1   # start with a clean event history for this demo
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
sleep 60
kubectl get pod containercreating-app -n s14
kubectl describe pod containercreating-app -n s14 | sed -n '/Volumes:/,/Optional/p'
kubectl events -n s14 --for pod/containercreating-app
kubectl get configmap -n s14
EOF
snap after --dir $D <<'EOF'
kubectl apply -f fixed.yaml
kubectl wait --for=condition=Ready pod/containercreating-app -n s14 --timeout=180s
kubectl get pod containercreating-app -n s14
kubectl exec containercreating-app -n s14 -- curl -s localhost
kubectl events -n s14 --for pod/containercreating-app | tail -n 4
EOF
kubectl delete -f fixed.yaml --wait=false >/dev/null
}

########## 06 Service connectivity ##########
s06() {
D=$B/06-service-connectivity; cd $D
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
kubectl rollout status deploy/shop-web -n s14 --timeout=90s
kubectl wait --for=condition=Ready pod/svc-client -n s14 --timeout=90s
kubectl exec svc-client -n s14 -- curl -sS -m 3 http://shop-web
kubectl get svc shop-web -n s14
kubectl get endpoints shop-web -n s14
kubectl get endpointslices -n s14 -l kubernetes.io/service-name=shop-web
kubectl describe svc shop-web -n s14 | grep -E 'Selector|TargetPort|Endpoints'
kubectl get pods -n s14 -l app=shop-web --show-labels
EOF
snap step1-fix-selector --dir $D <<'EOF'
kubectl patch svc shop-web -n s14 -p '{"spec":{"selector":{"app":"shop-web"}}}'
sleep 3
kubectl get endpoints shop-web -n s14
kubectl exec svc-client -n s14 -- curl -sS -m 3 http://shop-web
POD=$(kubectl get pods -n s14 -l app=shop-web -o jsonpath='{.items[0].metadata.name}'); POD_IP=$(kubectl get pod $POD -n s14 -o jsonpath='{.status.podIP}'); echo "$POD $POD_IP"
kubectl exec svc-client -n s14 -- curl -sS -m 3 -o /dev/null -w "direct pod:80 -> HTTP %{http_code}\n" http://$POD_IP:80
kubectl get pod $POD -n s14 -o jsonpath='containerPort={.spec.containers[0].ports[0].containerPort}{"\n"}'
kubectl get svc shop-web -n s14 -o jsonpath='service port={.spec.ports[0].port} targetPort={.spec.ports[0].targetPort}{"\n"}'
EOF
snap after --dir $D <<'EOF'
kubectl apply -f fixed.yaml
sleep 3
kubectl describe svc shop-web -n s14 | grep -E 'Selector|TargetPort|Endpoints'
kubectl get endpoints shop-web -n s14
kubectl exec svc-client -n s14 -- curl -sS -m 3 http://shop-web | grep -i '<title>'
kubectl exec svc-client -n s14 -- curl -sS -m 3 -o /dev/null -w "shop-web.s14.svc.cluster.local -> HTTP %{http_code}\n" http://shop-web.s14.svc.cluster.local
EOF
kubectl delete -f fixed.yaml --wait=false >/dev/null
}

########## 07 DNS ##########
s07() {
D=$B/07-dns; cd $D
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
kubectl rollout status deploy/orders-api -n s14-mini --timeout=90s
kubectl wait --for=condition=Ready pod/dns-client -n s14 --timeout=90s
sleep 12
kubectl logs dns-client -n s14 --tail=4
kubectl exec dns-client -n s14 -- nslookup orders-api
kubectl exec dns-client -n s14 -- cat /etc/resolv.conf
kubectl get svc -A | grep -E 'NAMESPACE|orders-api'
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl exec dns-client -n s14 -- nslookup kubernetes.default.svc.cluster.local
EOF
snap after --dir $D <<'EOF'
kubectl exec dns-client -n s14 -- nslookup orders-api.s14-mini.svc.cluster.local
kubectl delete pod dns-client -n s14 --wait=true
kubectl apply -f fixed.yaml
kubectl wait --for=condition=Ready pod/dns-client -n s14 --timeout=90s
sleep 12
kubectl logs dns-client -n s14 --tail=4
kubectl exec dns-client -n s14 -- printenv ORDERS_URL
EOF
kubectl delete pod dns-client -n s14 --wait=false >/dev/null
kubectl delete namespace s14-mini --wait=true >/dev/null
}

########## 08 Pod networking: NetworkPolicy ##########
s08() {
D=$B/08-pod-networking-networkpolicy; cd $D
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
kubectl wait --for=condition=Ready pod/payments-api pod/checkout -n s14 --timeout=90s
kubectl exec checkout -n s14 -- curl -sS -m 5 http://payments-api
kubectl get endpoints payments-api -n s14
kubectl exec checkout -n s14 -- nslookup payments-api.s14.svc.cluster.local 2>&1 | tail -n 3
kubectl exec payments-api -n s14 -- curl -s -o /dev/null -w "inside payments-api: localhost -> HTTP %{http_code}\n" localhost
kubectl get networkpolicy -n s14
kubectl describe networkpolicy default-deny-ingress -n s14
kubectl get pods -n kube-system -l app=kindnet
EOF
snap after --dir $D <<'EOF'
kubectl apply -f fixed.yaml
kubectl get networkpolicy -n s14
kubectl describe networkpolicy allow-checkout-to-payments -n s14 | sed -n '/Spec:/,$p'
sleep 3
kubectl exec checkout -n s14 -- curl -sS -m 5 http://payments-api | grep -i '<title>'
kubectl run intruder -n s14 --image=curlimages/curl:8.6.0 --restart=Never --labels=role=intruder --command -- sleep 600
kubectl wait --for=condition=Ready pod/intruder -n s14 --timeout=60s
kubectl exec intruder -n s14 -- curl -sS -m 5 http://payments-api
EOF
kubectl delete pod intruder -n s14 --wait=false >/dev/null
kubectl delete -f fixed.yaml -f broken.yaml --wait=false >/dev/null
}

########## 09 Configuration: CreateContainerConfigError ##########
s09() {
D=$B/09-config-createcontainerconfigerror; cd $D
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
sleep 10
kubectl get pod config-app -n s14
kubectl describe pod config-app -n s14 | sed -n '/State:/,/Environment:/p'
kubectl describe pod config-app -n s14 | sed -n '/Environment:/,/Mounts:/p'
kubectl events -n s14 --for pod/config-app
kubectl get configmap app-settings -n s14 -o jsonpath='{.data}{"\n"}'
EOF
snap after --dir $D <<'EOF'
kubectl delete pod config-app -n s14 --wait=true
kubectl apply -f fixed.yaml
kubectl wait --for=condition=Ready pod/config-app -n s14 --timeout=90s
kubectl get pod config-app -n s14
kubectl logs config-app -n s14
EOF
kubectl delete -f fixed.yaml --wait=false >/dev/null
}

########## 10 OOMKilled ##########
s10() {
D=$B/10-oomkilled; cd $D
snap before --dir $D <<'EOF'
kubectl apply -f broken.yaml
sleep 40
kubectl get pod oom-app -n s14
kubectl describe pod oom-app -n s14 | sed -n '/State:/,/Restart Count/p'
kubectl describe pod oom-app -n s14 | sed -n '/Limits:/,/Requests:/p'
kubectl get pod oom-app -n s14 -o jsonpath='{.status.containerStatuses[0].lastState.terminated}{"\n"}'
kubectl logs oom-app -n s14 --previous
EOF
snap after --dir $D <<'EOF'
kubectl delete pod oom-app -n s14 --wait=true
kubectl apply -f fixed.yaml
kubectl wait --for=condition=Ready pod/oom-app -n s14 --timeout=90s
sleep 60
kubectl get pod oom-app -n s14
kubectl logs oom-app -n s14
kubectl top pod oom-app -n s14
EOF
kubectl delete -f fixed.yaml --wait=false >/dev/null
}

SCENARIOS="${*:-01 02 03 04 05 06 07 08 09 10}"
for s in $SCENARIOS; do "s$s"; done
echo ALL-DONE
