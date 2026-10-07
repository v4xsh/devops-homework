#!/usr/bin/env bash
set -u
S=~/devops-homework/session-20-monitoring-observability-gitops
cd "$S"
B="$HOME/venv-s21/bin/python $S/scripts/browser_shot.py"
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep -B2 -A6 'Last State' | head -20
helm upgrade kps prometheus-community/kube-prometheus-stack -n monitoring -f task1-monitoring/helm-values/kube-prometheus-stack-values.yaml --wait --timeout 10m | head -5
kubectl rollout status deploy/kps-grafana -n monitoring
sleep 15
until curl -sf localhost:13000/api/health >/dev/null; do sleep 3; done
$B "http://localhost:13000/d/s20-metrics-app?orgId=1&from=now-1h&to=now" screenshots/browser/grafana-s20-dashboard.png --grafana-login admin:s20-grafana-admin --height 1150 --wait-ms 10000
$B "http://localhost:13000/d/85a562078cdf77779eaa1add43ccec1e?orgId=1&var-datasource=prometheus&var-namespace=s20-app&from=now-1h&to=now" screenshots/browser/grafana-k8s-namespace-cpu-memory.png --grafana-login admin:s20-grafana-admin --height 1150 --wait-ms 10000
