#!/usr/bin/env bash
# Final project - monitoring: reuse the session-20 kube-prometheus-stack (namespace monitoring) to scrape TaskBoard.
# Needs the port-forwards from session-20 scripts/port-forwards.sh (19090 Prometheus, 13000 Grafana).
set -u
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
B="$HOME/venv-s21/bin/python $P/scripts/browser_shot.py"
PQ=~/devops-homework/session-20-monitoring-observability-gitops/scripts/promq.sh

# export the monitoring objects exactly as the chart renders them for the final-app release
helm template taskboard helm/taskboard -n final-app --api-versions monitoring.coreos.com/v1 --show-only templates/monitoring.yaml > monitoring/taskboard-monitoring-rendered.yaml
helm template taskboard helm/taskboard -n final-app --show-only templates/monitoring.yaml \
  | yq -r '.data["taskboard-final-app.json"]' > monitoring/grafana-dashboard-taskboard.json 2>/dev/null \
  || sed 's/__NAMESPACE__/final-app/g; s/__SERVICE__/taskboard-backend/g' helm/taskboard/dashboards/taskboard.json > monitoring/grafana-dashboard-taskboard.json
cp ~/devops-homework/session-20-monitoring-observability-gitops/task1-monitoring/helm-values/kube-prometheus-stack-values.yaml monitoring/kube-prometheus-stack-values.yaml

snap 25-metrics-and-scrape-target --dir "$P" <<'EOF'
kubectl get servicemonitor,prometheusrule -n final-app
kubectl port-forward -n final-app svc/taskboard-backend 18000:8000 > /dev/null 2>&1 & sleep 3
curl -s localhost:18000/metrics | grep -E '^(http_requests_total|taskboard_tasks_created_total|taskboard_app_info)' | head -n 12
kill %1
curl -s localhost:19090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.namespace=="final-app") | [.labels.job, .labels.pod, .scrapeUrl, .health] | @tsv' | column -t
EOF

snap 26-promql-taskboard --dir "$P" <<'EOF'
PQ=~/devops-homework/session-20-monitoring-observability-gitops/scripts/promq.sh
$PQ 'up{namespace="final-app", service="taskboard-backend"}' | sed 's/container="backend", //'
$PQ 'sum by (handler, method, status) (increase(http_requests_total{namespace="final-app", service="taskboard-backend"}[30m]))' | sort -t'>' -k2 -rn | head -n 8
$PQ 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="final-app", service="taskboard-backend"}[30m])))'
$PQ 'sum by (priority) (taskboard_tasks_created_total{namespace="final-app"})'
$PQ 'max_over_time(kube_horizontalpodautoscaler_status_current_replicas{namespace="final-app"}[30m])'
$PQ 'sum by (pod) (container_memory_working_set_bytes{namespace="final-app", container!=""}) / 1024 / 1024'
curl -s localhost:19090/api/v1/rules | jq -r '.data.groups[] | select(.name=="taskboard.rules") | .rules[] | [.name, .state, .health] | @tsv' | column -t
EOF

$B "http://localhost:19090/targets?search=final-app" screenshots/browser/prometheus-targets-final-app.png --wait-ms 3000
$B "http://localhost:13000/d/taskboard-final-app?orgId=1&from=now-1h&to=now" screenshots/browser/grafana-taskboard-dashboard.png --grafana-login admin:s20-grafana-admin --height 1000 --wait-ms 10000
$B "http://localhost:19090/alerts?search=taskboard" screenshots/browser/prometheus-taskboard-rules.png --wait-ms 3000
