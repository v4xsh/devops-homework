#!/usr/bin/env bash
# Session 20 - Alertmanager capture, restore the app (alert resolves), PromQL CPU/memory/app queries,
# Grafana API, Jaeger traces and real browser captures of the UIs.
# Port-forwards are kept alive by scripts/port-forwards.sh (19090 prom, 19093 alertmanager, 13000 grafana, 16686 jaeger).
set -u
S=~/devops-homework/session-20-monitoring-observability-gitops
cd "$S"
B="$HOME/venv-s21/bin/python $S/scripts/browser_shot.py"
mkdir -p screenshots/browser
$B "http://localhost:19093/#/alerts" screenshots/browser/alertmanager-appdown-active.png --wait-ms 2000 --click-text "Expand all groups"

snap 12-alert-resolved --dir "$S" <<'EOF'
kubectl scale deploy/s20-metrics-app -n s20-app --replicas=2
kubectl rollout status deploy/s20-metrics-app -n s20-app --timeout=120s
sleep 60
curl -s localhost:19090/api/v1/query --data-urlencode 'query=up{namespace="s20-app"}' | jq -r '.data.result[] | "\(.metric.pod)  up=\(.value[1])"'
curl -s localhost:19090/api/v1/alerts | jq -r '[.data.alerts[] | select(.labels.alertname=="AppDown")] | if length==0 then "AppDown: no longer active (resolved)" else .[] | "AppDown: \(.state)" end'
curl -s localhost:19090/api/v1/rules | jq -r '.data.groups[] | select(.name=="s20-metrics-app.rules") | .rules[] | [.name, .state] | @tsv' | column -t
EOF

echo "waiting for fresh rate() windows..."; sleep 90

snap 06-promql-cpu-memory --dir "$S" <<'EOF'
tail -n 4 scripts/promq.sh
curl -s -G localhost:19090/api/v1/query --data-urlencode 'query=sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="s20-app",container!=""}[2m]))' | jq -c '.data.result[] | {pod: .metric.pod, cpu_cores: .value[1]}'
scripts/promq.sh 'sum by (pod) (container_memory_working_set_bytes{namespace="s20-app",container!=""}) / 1024 / 1024'
scripts/promq.sh 'topk(5, sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m])))'
scripts/promq.sh '100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))'
scripts/promq.sh '100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'
kubectl top pods -n s20-app
EOF

snap 07-promql-app-metrics --dir "$S" <<'EOF'
scripts/promq.sh 'up{namespace="s20-app"}'
scripts/promq.sh 'sum by (endpoint, status) (rate(app_requests_total{namespace="s20-app"}[2m]))'
scripts/promq.sh 'sum by (endpoint, status) (app_requests_total{namespace="s20-app"})'
scripts/promq.sh 'histogram_quantile(0.95, sum by (le, endpoint) (rate(app_request_duration_seconds_bucket{namespace="s20-app"}[2m])))'
scripts/promq.sh 'sum(rate(app_requests_total{namespace="s20-app",status=~"5.."}[2m])) / sum(rate(app_requests_total{namespace="s20-app"}[2m]))'
scripts/promq.sh 'kube_deployment_status_replicas_available{namespace="s20-app"}'
EOF

snap 08-logs --dir "$S" <<'EOF'
kubectl logs -n s20-app deploy/s20-metrics-app --tail=6
kubectl logs -n s20-app -l app=s20-metrics-app --tail=300 --prefix | grep '"level": "ERROR"' | tail -n 3
kubectl logs -n s20-app -l app=s20-metrics-app --tail=500 | jq -r 'select(.status != null) | .status' | sort | uniq -c
kubectl logs -n s20-app deploy/jaeger --tail=200 | grep -iE 'Starting|ready|listening' | head -n 4 | cut -c1-200
kubectl get events -n s20-app --sort-by=.lastTimestamp | tail -n 6
EOF

snap 13-grafana-api --dir "$S" <<'EOF'
curl -s localhost:13000/api/health | jq -c .
curl -s -u admin:s20-grafana-admin localhost:13000/api/datasources | jq -r '.[] | [.uid, .name, .type, .url] | @tsv' | column -t
curl -s -u admin:s20-grafana-admin 'localhost:13000/api/search?type=dash-db' | jq -r '.[] | [.uid, .title] | @tsv' | grep -E 's20|Compute Resources / Namespace \(Pods\)|Node Exporter / Nodes'
curl -s -u admin:s20-grafana-admin localhost:13000/api/dashboards/uid/s20-metrics-app | jq -r '.dashboard.panels[] | "panel \(.id): \(.title)"'
curl -s -u admin:s20-grafana-admin -G localhost:13000/api/datasources/proxy/uid/prometheus/api/v1/query --data-urlencode 'query=sum(rate(app_requests_total{namespace="s20-app"}[1m]))' | jq -c '.data.result'
EOF

snap 14-jaeger-traces --dir "$S" <<'EOF'
kubectl get deploy s20-metrics-app -n s20-app -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}'
curl -s localhost:16686/api/services | jq -c .
curl -s 'localhost:16686/api/traces?service=s20-metrics-app&operation=GET%20%2Fwork&limit=1' | jq -r '.data[0] | "traceID=\(.traceID)  spans=\(.spans|length)", (.spans[] | "  \(.operationName)  \(.duration)us")'
curl -s 'localhost:16686/api/traces?service=s20-metrics-app&limit=200&lookback=1h' | jq '[.data[]] | length'
EOF

# ---- real browser captures ----
$B "http://localhost:19090/targets?search=s20" screenshots/browser/prometheus-targets.png --wait-ms 3000
$B "http://localhost:19090/query?g0.expr=sum%20by%20(endpoint%2C%20status)%20(rate(app_requests_total%7Bnamespace%3D%22s20-app%22%7D%5B1m%5D))&g0.tab=graph&g0.range_input=30m" screenshots/browser/prometheus-graph-request-rate.png --wait-ms 4000
$B "http://localhost:19090/query?g0.expr=sum%20by%20(pod)%20(rate(container_cpu_usage_seconds_total%7Bnamespace%3D%22s20-app%22%2Ccontainer!%3D%22%22%7D%5B2m%5D))&g0.tab=graph&g0.range_input=30m" screenshots/browser/prometheus-graph-cpu.png --wait-ms 4000
$B "http://localhost:13000/d/s20-metrics-app?orgId=1&from=now-30m&to=now" screenshots/browser/grafana-s20-dashboard.png --grafana-login admin:s20-grafana-admin --height 1150 --wait-ms 8000
UID_NS=$(curl -s -u admin:s20-grafana-admin 'localhost:13000/api/search?query=Compute%20Resources%20%2F%20Namespace%20(Pods)' | jq -r '.[0].uid')
$B "http://localhost:13000/d/$UID_NS?orgId=1&var-datasource=prometheus&var-cluster=&var-namespace=s20-app&from=now-30m&to=now" screenshots/browser/grafana-k8s-namespace-cpu-memory.png --grafana-login admin:s20-grafana-admin --height 1150 --wait-ms 8000
TRACE=$(curl -s 'localhost:16686/api/traces?service=s20-metrics-app&operation=GET%20%2Fwork&limit=1' | jq -r '.data[0].traceID')
$B "http://localhost:16686/search?service=s20-metrics-app&limit=20" screenshots/browser/jaeger-search.png --wait-ms 4000
$B "http://localhost:16686/trace/$TRACE" screenshots/browser/jaeger-trace-detail.png --wait-ms 4000
