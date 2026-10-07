#!/usr/bin/env bash
# Session 11 / Task 2 - real evidence for the object comparisons (namespace s11)
set -u
D=~/devops-homework/session-11-kubernetes-networking-services/object-comparison
cd $D

snap 01-deployment-owns-replicaset --dir $D <<'EOF'
kubectl apply -f deployment.yaml
kubectl rollout status deployment/demo-deploy -n s11 --timeout=120s
kubectl get deploy,rs,pods -n s11 -l app=demo-deploy
kubectl get rs -n s11 -l app=demo-deploy -o custom-columns='RS:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name,CONTROLLER:.metadata.ownerReferences[0].controller'
kubectl get pods -n s11 -l app=demo-deploy -o custom-columns='POD:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name,HASH:.metadata.labels.pod-template-hash'
EOF

snap 02-deployment-rolling-update --dir $D <<'EOF'
kubectl set image deployment/demo-deploy nginx=nginx:1.27-alpine -n s11
kubectl annotate deployment/demo-deploy kubernetes.io/change-cause="upgrade nginx 1.25 -> 1.27" -n s11 --overwrite
kubectl rollout status deployment/demo-deploy -n s11 --timeout=180s
kubectl get rs -n s11 -l app=demo-deploy -o wide
kubectl rollout history deployment/demo-deploy -n s11
kubectl describe deployment demo-deploy -n s11 | sed -n '/Events:/,$p'
EOF

snap 03-deployment-rollback-and-scale --dir $D <<'EOF'
kubectl rollout undo deployment/demo-deploy -n s11
kubectl rollout status deployment/demo-deploy -n s11 --timeout=180s
kubectl scale deployment/demo-deploy --replicas=5 -n s11
kubectl rollout status deployment/demo-deploy -n s11 --timeout=120s
kubectl get rs -n s11 -l app=demo-deploy -o wide
EOF

snap 04-bare-replicaset-no-rollout --dir $D <<'EOF'
kubectl apply -f replicaset.yaml
sleep 8
kubectl get rs,pods -n s11 -l app=bare-rs
echo "--- self-healing: delete one pod, the RS recreates it"
kubectl delete pod -n s11 $(kubectl get pods -n s11 -l app=bare-rs -o jsonpath='{.items[0].metadata.name}') --wait=true
sleep 4
kubectl get pods -n s11 -l app=bare-rs
echo "--- change the RS image: existing pods are NOT updated (a RS has no rollout logic)"
kubectl set image rs/bare-rs nginx=nginx:1.27-alpine -n s11
sleep 4
kubectl get rs bare-rs -n s11 -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl get pods -n s11 -l app=bare-rs -o custom-columns='POD:.metadata.name,IMAGE:.spec.containers[0].image'
EOF

snap 05-daemonset-vs-statefulset --dir $D <<'EOF'
kubectl get nodes
kubectl apply -f daemonset.yaml
kubectl apply -f statefulset-with-storage.yaml
kubectl rollout status daemonset/node-agent -n s11 --timeout=120s
kubectl rollout status statefulset/db -n s11 --timeout=180s
kubectl get ds,sts -n s11
kubectl get pods -n s11 -l 'app in (node-agent,db)' -o wide
kubectl get pvc -n s11
kubectl logs -n s11 -l app=node-agent --tail=1
EOF

snap 06-statefulset-identity --dir $D <<'EOF'
kubectl exec -n s11 db-0 -- cat /data/identity.txt
kubectl delete pod db-0 -n s11 --wait=true
kubectl wait --for=condition=Ready pod/db-0 -n s11 --timeout=120s
kubectl get pods -n s11 -l app=db -o wide
kubectl exec -n s11 db-0 -- cat /data/identity.txt
kubectl exec -n s11 dnsutils -- dig +short db-1.db-headless.s11.svc.cluster.local
EOF

snap 07-service-traffic-path --dir $D --max-lines 90 <<'EOF'
kubectl get svc web-service-clusterip -n s11
kubectl get endpointslices -n s11 -l kubernetes.io/service-name=web-service-clusterip -o wide
kubectl get pods -n s11 -l app=web-clusterip -o custom-columns=POD:.metadata.name,IP:.status.podIP
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=200 | grep -i "proxier" | head -3
minikube ssh -- sudo iptables -t nat -L KUBE-SERVICES -n | grep -E "s11/web-service-clusterip"
SVCCHAIN=$(minikube ssh -- sudo iptables -t nat -L KUBE-SERVICES -n | grep "s11/web-service-clusterip" | awk '{print $1}' | tr -d '\r'); echo "service chain: $SVCCHAIN"
minikube ssh -- sudo iptables -t nat -L $SVCCHAIN -n
EOF
