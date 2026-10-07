#!/usr/bin/env bash
# Session 20 / Task 1 - build the sample app, install kube-prometheus-stack, deploy app + ServiceMonitor + rules.
set -u
S=~/devops-homework/session-20-monitoring-observability-gitops
cd "$S"

snap 01-build-sample-app --dir "$S" <<'EOF'
cd task1-monitoring/sample-app
cat Dockerfile
docker build -t s20-metrics-app:1.0.0 . 2>&1 | tail -n 8
docker images s20-metrics-app
minikube image load s20-metrics-app:1.0.0 && minikube image ls | grep s20-metrics-app
EOF

snap 02-helm-install-kube-prometheus-stack --dir "$S" <<'EOF'
helm repo list | grep prometheus-community
helm upgrade --install kps prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f task1-monitoring/helm-values/kube-prometheus-stack-values.yaml --wait --timeout 10m 2>&1 | head -n 12
helm list -n monitoring
kubectl get pods -n monitoring -o wide
kubectl get svc -n monitoring
EOF

snap 03-deploy-sample-app --dir "$S" <<'EOF'
kubectl apply -f task1-monitoring/k8s/app.yaml
kubectl apply -f task2-observability/otel-jaeger/jaeger.yaml
kubectl apply -f task1-monitoring/k8s/servicemonitor.yaml -f task1-monitoring/k8s/prometheusrule.yaml
kubectl apply -f task1-monitoring/grafana/dashboard-configmap.yaml
kubectl rollout status deploy/s20-metrics-app -n s20-app --timeout=180s
kubectl rollout status deploy/jaeger -n s20-app --timeout=180s
kubectl get deploy,pods,svc,servicemonitor,prometheusrule -n s20-app
EOF
