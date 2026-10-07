#!/usr/bin/env bash
# Session 09 - Minikube setup verification + architecture exploration (real runs captured with snap)
set -u
D=~/devops-homework/session-09-kubernetes-fundamentals
cd "$D"

# 01 - Install demo: download the official minikube + kubectl binaries into a scratch dir
#      (the cluster's own minikube is already installed in /usr/local/bin; this proves the install commands work)
snap 01-minikube-install --dir "$D" <<'EOF'
mkdir -p /tmp/s09-install && cd /tmp/s09-install
curl -sSLo minikube-linux-amd64 https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && ls -lh minikube-linux-amd64
curl -sSLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && ls -lh kubectl
chmod +x minikube-linux-amd64 kubectl && ./minikube-linux-amd64 version && ./kubectl version --client
which minikube kubectl docker
docker version --format 'Docker client {{.Client.Version}} / server {{.Server.Version}}'
cd /tmp && rm -rf /tmp/s09-install
EOF

snap 02-cluster-status --dir "$D" <<'EOF'
minikube version
minikube status
minikube profile list
kubectl version
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
EOF

snap 03-kube-system-pods --dir "$D" <<'EOF'
kubectl get pods -n kube-system -o wide
minikube ssh -- sudo ls -l /etc/kubernetes/manifests
kubectl get pods -n kube-system -l tier=control-plane -o custom-columns=NAME:.metadata.name,COMPONENT:.metadata.labels.component,STATIC-POD-OWNER:.metadata.ownerReferences[0].kind
kubectl get daemonset,deployment -n kube-system
EOF

snap 04-control-plane-health --dir "$D" --max-lines 90 <<'EOF'
kubectl get componentstatuses
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez'; echo
kubectl get --raw='/version'
EOF

snap 05-node-components --dir "$D" --max-lines 90 <<'EOF'
minikube ssh -- sudo systemctl is-active kubelet containerd
minikube ssh -- "sudo systemctl status kubelet --no-pager | head -n 8"
minikube ssh -- "sudo crictl ps | grep -E 'NAME|kube-|etcd|coredns'"
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=5
kubectl describe node minikube | sed -n '/Capacity:/,/System Info:/p'
EOF

snap 06-addons --dir "$D" <<'EOF'
minikube addons list
EOF

snap 07-basic-objects --dir "$D" --max-lines 80 <<'EOF'
kubectl api-resources --api-group='' | head -n 20
kubectl api-resources --api-group=apps
kubectl get namespaces
kubectl explain pod.spec.containers | head -n 15
EOF
