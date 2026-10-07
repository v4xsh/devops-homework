#!/usr/bin/env bash
# Session 20 - re-run the app PromQL queries + dashboard capture after the honorLabels fix.
set -u
S=~/devops-homework/session-20-monitoring-observability-gitops
cd "$S"
B="$HOME/venv-s21/bin/python $S/scripts/browser_shot.py"
snap 15b-after-honorlabels --dir "$S" <<'XEOF'
curl -s localhost:19090/api/v1/status/config | jq -r .data.yaml | grep -A2 'job_name: serviceMonitor/s20-app/s20-metrics-app/0'
scripts/promq.sh 'sum by (endpoint, status) (rate(app_requests_total{namespace="s20-app"}[1m]))'
XEOF
snap 07-promql-app-metrics --dir "$S" <<'XEOF'
scripts/promq.sh 'up{namespace="s20-app", service="s20-metrics-app"}'
scripts/promq.sh 'sum by (endpoint, status) (rate(app_requests_total{namespace="s20-app"}[2m]))'
scripts/promq.sh 'sum by (endpoint, status) (app_requests_total{namespace="s20-app"})'
scripts/promq.sh 'histogram_quantile(0.95, sum by (le, endpoint) (rate(app_request_duration_seconds_bucket{namespace="s20-app"}[2m])))'
scripts/promq.sh 'sum(rate(app_requests_total{namespace="s20-app",status=~"5.."}[2m])) / sum(rate(app_requests_total{namespace="s20-app"}[2m]))'
scripts/promq.sh 'sum by (deployment) (kube_deployment_status_replicas_available{namespace="s20-app"})'
XEOF
$B "http://localhost:13000/d/s20-metrics-app?orgId=1&from=now-1h&to=now" screenshots/browser/grafana-s20-dashboard.png --grafana-login admin:s20-grafana-admin --height 1150 --wait-ms 10000
$B "http://localhost:19090/query?g0.expr=sum%20by%20(endpoint%2C%20status)%20(rate(app_requests_total%7Bnamespace%3D%22s20-app%22%7D%5B1m%5D))&g0.tab=graph&g0.range_input=1h" screenshots/browser/prometheus-graph-request-rate.png --wait-ms 4000
