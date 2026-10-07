#!/usr/bin/env bash
D=~/devops-homework/session-14-kubernetes-troubleshooting/01-kubectl-commands
cd $D
kubectl create namespace s14 --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -f demo-app.yaml >/dev/null
kubectl rollout status deploy/web -n s14 --timeout=120s >/dev/null
kubectl wait --for=condition=Ready pod/multi -n s14 --timeout=120s >/dev/null
sleep 40   # let restarter restart a couple of times and metrics be collected
snap 01-kubectl-get --dir $D <<'EOF'
kubectl get nodes
kubectl get pods -n s14
kubectl get all -n s14
kubectl get pods -n s14 --show-labels
kubectl get pods -n s14 -l app=web,tier=frontend
kubectl get pods -n s14 --field-selector status.phase=Running
EOF
snap 02-kubectl-describe --dir $D --max-lines 90 <<'EOF'
POD=$(kubectl get pods -n s14 -l app=web -o jsonpath='{.items[0].metadata.name}'); echo $POD
kubectl describe pod $POD -n s14
kubectl describe svc web -n s14
kubectl describe node minikube | sed -n '/Allocated resources/,/Events/p'
EOF
snap 03-kubectl-logs --dir $D <<'EOF'
kubectl logs deploy/web -n s14 --tail=4
kubectl logs multi -n s14 -c sidecar --tail=3
kubectl logs multi -n s14 -c sidecar --since=12s --timestamps
kubectl logs -n s14 -l app=web --prefix --tail=2
kubectl get pod restarter -n s14
kubectl logs restarter -n s14 --previous
kubectl logs multi -n s14 2>&1 | head -3
EOF
snap 04-kubectl-exec --dir $D <<'EOF'
POD=$(kubectl get pods -n s14 -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -n s14 -- nginx -v
kubectl exec $POD -n s14 -- cat /etc/resolv.conf
kubectl exec $POD -n s14 -- sh -c 'env | grep ^WEB_SERVICE'
kubectl exec multi -n s14 -c sidecar -- ps
kubectl exec multi -n s14 -c sidecar -- wget -qO- -T 3 http://web.s14.svc.cluster.local | grep -i title
kubectl exec multi -n s14 -c sidecar -- nslookup web.s14.svc.cluster.local
EOF
snap 05-kubectl-events --dir $D <<'EOF'
kubectl events -n s14 --for pod/restarter
kubectl get events -n s14 --sort-by=.lastTimestamp | tail -n 12
kubectl get events -n s14 --field-selector type=Warning
kubectl events -n s14 --types=Warning
EOF
snap 06-kubectl-explain --dir $D <<'EOF'
kubectl explain pod.spec.containers.livenessProbe | head -n 25
kubectl explain deployment.spec.strategy --recursive
kubectl explain service.spec.type | head -n 15
EOF
snap 07-kubectl-top --dir $D <<'EOF'
kubectl top nodes
kubectl top pods -n s14
kubectl top pods -n s14 --containers
kubectl top pods -n kube-system --sort-by=memory
EOF
snap 08-kubectl-output-formats --dir $D <<'EOF'
kubectl get pods -n s14 -o wide
kubectl get pods -n s14 -o name
kubectl get pod multi -n s14 -o yaml | head -n 30
kubectl get pods -n s14 -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
kubectl get pods -n s14 -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,IMAGE:.spec.containers[0].image,PHASE:.status.phase
kubectl get svc web -n s14 -o jsonpath='{.spec.clusterIP}:{.spec.ports[0].port}{"\n"}'
EOF
kubectl delete -f demo-app.yaml --wait=false >/dev/null
