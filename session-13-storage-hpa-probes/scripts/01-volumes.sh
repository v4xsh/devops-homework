#!/usr/bin/env bash
# Runs the Task 1 volume demos and captures real screenshots with snap.
D=~/devops-homework/session-13-storage-hpa-probes/01-kubernetes-volumes
cd $D
snap 00-storageclass-and-namespace --dir $D <<'EOF'
kubectl apply -f namespace.yaml
kubectl get storageclass
kubectl describe storageclass standard
kubectl get pods -n kube-system -l integration-test=storage-provisioner -o wide
EOF
snap 01-emptydir-shared --dir $D <<'EOF'
kubectl apply -f 01-emptydir-shared.yaml
kubectl wait --for=condition=Ready pod/emptydir-shared -n s13 --timeout=120s
sleep 12
kubectl get pod emptydir-shared -n s13 -o wide
kubectl exec emptydir-shared -n s13 -c writer -- ls -l /shared
kubectl exec emptydir-shared -n s13 -c reader -- cat /usr/share/nginx/html/heartbeat.log
kubectl exec emptydir-shared -n s13 -c reader -- curl -s localhost/index.html
kubectl exec emptydir-shared -n s13 -c reader -- sh -c 'touch /usr/share/nginx/html/x 2>&1 || true'
kubectl exec emptydir-shared -n s13 -c reader -- df -h /usr/share/nginx/html
EOF
snap 02-emptydir-lost-on-delete --dir $D <<'EOF'
kubectl exec emptydir-shared -n s13 -c writer -- wc -l /shared/heartbeat.log
kubectl delete pod emptydir-shared -n s13
kubectl apply -f 01-emptydir-shared.yaml
kubectl wait --for=condition=Ready pod/emptydir-shared -n s13 --timeout=120s
kubectl exec emptydir-shared -n s13 -c writer -- wc -l /shared/heartbeat.log
kubectl exec emptydir-shared -n s13 -c writer -- cat /shared/heartbeat.log
EOF
snap 03-hostpath --dir $D <<'EOF'
kubectl apply -f 02-hostpath-pod.yaml
kubectl wait --for=condition=Ready pod/hostpath-demo -n s13 --timeout=120s
kubectl exec hostpath-demo -n s13 -- cat /host-data/hostpath.log
docker exec minikube ls -l /tmp/s13-hostpath-data
docker exec minikube cat /tmp/s13-hostpath-data/hostpath.log
kubectl delete pod hostpath-demo -n s13
kubectl apply -f 02-hostpath-pod.yaml
kubectl wait --for=condition=Ready pod/hostpath-demo -n s13 --timeout=120s
kubectl exec hostpath-demo -n s13 -- cat /host-data/hostpath.log
EOF
snap 04-static-pv-pvc-bound --dir $D <<'EOF'
kubectl apply -f 03-static-pv.yaml
kubectl get pv s13-static-pv
kubectl apply -f 04-static-pvc.yaml
sleep 3
kubectl get pv s13-static-pv
kubectl get pvc static-pvc -n s13
kubectl describe pvc static-pvc -n s13
EOF
snap 05-static-pv-data-persists --dir $D <<'EOF'
kubectl apply -f 05-static-pod.yaml
kubectl wait --for=condition=Ready pod/static-pv-pod -n s13 --timeout=120s
kubectl exec static-pv-pod -n s13 -- sh -c 'echo "Vansh Dobhal 10099 - static PV data" > /data/student.txt; cat /data/student.txt'
kubectl delete pod static-pv-pod -n s13
kubectl apply -f 05-static-pod.yaml
kubectl wait --for=condition=Ready pod/static-pv-pod -n s13 --timeout=120s
kubectl exec static-pv-pod -n s13 -- cat /data/student.txt
docker exec minikube cat /tmp/s13-static-pv/student.txt
EOF
snap 06-dynamic-provisioning --dir $D <<'EOF'
kubectl get pv
kubectl apply -f 06-dynamic-pvc.yaml
sleep 5
kubectl get pvc dynamic-pvc -n s13
kubectl get pv
kubectl describe pvc dynamic-pvc -n s13
PV=$(kubectl get pvc dynamic-pvc -n s13 -o jsonpath='{.spec.volumeName}'); echo "Auto-created PV: $PV"
kubectl get pv $PV -o jsonpath='{.metadata.annotations}{"\n"}{.spec.hostPath.path}{"\n"}{.spec.persistentVolumeReclaimPolicy}{"\n"}'
EOF
snap 07-dynamic-data-persists --dir $D <<'EOF'
kubectl apply -f 07-dynamic-pod.yaml
kubectl wait --for=condition=Ready pod/dynamic-pv-pod -n s13 --timeout=120s
kubectl exec dynamic-pv-pod -n s13 -- sh -c 'echo "<h1>Stored on a dynamically provisioned PV - Vansh Dobhal 10099</h1>" > /usr/share/nginx/html/index.html'
kubectl exec dynamic-pv-pod -n s13 -- curl -s localhost
kubectl delete pod dynamic-pv-pod -n s13
kubectl get pvc dynamic-pvc -n s13
kubectl apply -f 07-dynamic-pod.yaml
kubectl wait --for=condition=Ready pod/dynamic-pv-pod -n s13 --timeout=120s
kubectl get pod dynamic-pv-pod -n s13 -o wide
kubectl exec dynamic-pv-pod -n s13 -- curl -s localhost
EOF
snap 08-reclaim-policy --dir $D <<'EOF'
kubectl get pv -o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimRef.name,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLASS:.spec.storageClassName | grep -E 'NAME|s13-static-pv|dynamic-pvc'
PV=$(kubectl get pvc dynamic-pvc -n s13 -o jsonpath='{.spec.volumeName}'); echo "dynamic PV = $PV"
kubectl delete pod dynamic-pv-pod static-pv-pod -n s13
kubectl delete pvc dynamic-pvc static-pvc -n s13
sleep 8
kubectl get pv s13-static-pv
kubectl get pv $PV 2>&1
docker exec minikube cat /tmp/s13-static-pv/student.txt
EOF
snap 09-cleanup --dir $D <<'EOF'
kubectl delete pv s13-static-pv
kubectl delete pod emptydir-shared hostpath-demo -n s13 --wait=false
docker exec minikube rm -rf /tmp/s13-static-pv /tmp/s13-hostpath-data
kubectl get pv,pvc -n s13 2>&1 | grep -E 's13|No resources' || echo "no s13 PV/PVC left"
EOF
