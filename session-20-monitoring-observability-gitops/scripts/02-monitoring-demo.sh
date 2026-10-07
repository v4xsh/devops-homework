#!/usr/bin/env bash
# Session 20 / Task 1 - metrics, PromQL (CPU/memory/up/app counters), logs, health, alerts.
set -u
S=~/devops-homework/session-20-monitoring-observability-gitops
cd "$S"
chmod +x scripts/promq.sh
export PATH="$S/scripts:$PATH"
pkill -f "port-forward.*1909[03]" 2>/dev/null; pkill -f "port-forward.*18081" 2>/dev/null; pkill -f "port-forward.*13000" 2>/dev/null; pkill -f "port-forward.*16686" 2>/dev/null

kubectl apply -f task1-monitoring/k8s/loadgen.yaml
kubectl rollout status deploy/loadgen -n s20-app --timeout=120s
echo "letting traffic + scrapes accumulate..."; sleep 120

snap 04-app-metrics-endpoint --dir "$S" <<'EOF'
kubectl get pods -n s20-app -l 'app in (s20-metrics-app,loadgen)'
kubectl port-forward -n s20-app svc/s20-metrics-app 18081:80 > /tmp/pf-app.log 2>&1 &
sleep 3
curl -s localhost:18081/ ; echo
curl -s -w '  HTTP %{http_code}\n' localhost:18081/healthz
curl -s -w '  HTTP %{http_code}\n' localhost:18081/readyz
curl -s localhost:18081/metrics | grep -E '^app_' | grep -v '_bucket' | head -n 20
EOF

snap 05-prometheus-targets --dir "$S" <<'EOF'
kubectl port-forward -n monitoring svc/kps-prometheus 19090:9090 > /tmp/pf-prom.log 2>&1 &
sleep 3
curl -s localhost:19090/-/ready
curl -s localhost:19090/api/v1/targets | jq -r '.data.activeTargets[] | [.labels.job, .labels.instance, .health, .lastScrapeDuration] | @tsv' | sort | column -t
EOF

snap 06-promql-cpu-memory --dir "$S" <<'EOF'
cat scripts/promq.sh | tail -n 4
curl -s -G localhost:19090/api/v1/query --data-urlencode 'query=sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="s20-app",container!=""}[2m]))' | jq -c '.data.result[] | {pod: .metric.pod, cpu_cores: .value[1]}'
promq 'sum by (pod) (container_memory_working_set_bytes{namespace="s20-app",container!=""}) / 1024 / 1024'
promq 'sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))'
promq '100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))'
promq '100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'
kubectl top pods -n s20-app
EOF

snap 07-promql-app-metrics --dir "$S" <<'EOF'
promq 'up{namespace="s20-app"}'
promq 'sum by (endpoint, status) (rate(app_requests_total{namespace="s20-app"}[2m]))'
promq 'sum by (endpoint, status) (app_requests_total{namespace="s20-app"})'
promq 'histogram_quantile(0.95, sum by (le, endpoint) (rate(app_request_duration_seconds_bucket{namespace="s20-app"}[2m])))'
promq 'sum(rate(app_requests_total{namespace="s20-app",status=~"5.."}[2m])) / sum(rate(app_requests_total{namespace="s20-app"}[2m]))'
promq 'kube_deployment_status_replicas_available{namespace="s20-app"}'
EOF

snap 08-logs --dir "$S" <<'EOF'
kubectl logs -n s20-app deploy/s20-metrics-app --tail=6
kubectl logs -n s20-app -l app=s20-metrics-app --tail=200 --prefix | grep '"level": "ERROR"' | tail -n 3
kubectl logs -n s20-app -l app=s20-metrics-app --tail=500 | grep -c '"status": 500'
kubectl logs -n s20-app deploy/loadgen --tail=3
kubectl get events -n s20-app --sort-by=.lastTimestamp | tail -n 8
EOF

snap 09-health-probes --dir "$S" <<'EOF'
kubectl get --raw '/readyz?verbose' | tail -n 6
kubectl get --raw '/livez'; echo
kubectl get pods -n s20-app -l app=s20-metrics-app -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,STATUS:.status.phase
kubectl describe pod -n s20-app -l app=s20-metrics-app | grep -E '^Name:|Liveness|Readiness' | head -n 6
kubectl get endpoints s20-metrics-app -n s20-app
kubectl get nodes -o custom-columns=NAME:.metadata.name,READY:'.status.conditions[?(@.type=="Ready")].status',MEMPRESSURE:'.status.conditions[?(@.type=="MemoryPressure")].status',DISKPRESSURE:'.status.conditions[?(@.type=="DiskPressure")].status'
EOF

snap 10-alert-rules-loaded --dir "$S" <<'EOF'
kubectl get prometheusrule -n s20-app s20-metrics-app-alerts -o jsonpath='{range .spec.groups[0].rules[*]}{.alert}{"\t"}{.expr}{"\n"}{end}' | cut -c1-140
curl -s localhost:19090/api/v1/rules | jq -r '.data.groups[] | select(.name=="s20-metrics-app.rules") | .rules[] | [.name, .state, .health] | @tsv' | column -t
EOF

snap 11-alert-firing-appdown --dir "$S" <<'EOF'
kubectl scale deploy/s20-metrics-app -n s20-app --replicas=0
kubectl wait --for=delete pod -l app=s20-metrics-app -n s20-app --timeout=60s
sleep 30
curl -s localhost:19090/api/v1/alerts | jq -r '.data.alerts[] | select(.labels.alertname=="AppDown") | [.labels.alertname, .labels.severity, .state, .activeAt] | @tsv'
sleep 45
curl -s localhost:19090/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname=="AppDown")'
kubectl port-forward -n monitoring svc/kps-alertmanager 19093:9093 > /tmp/pf-am.log 2>&1 &
sleep 20
curl -s localhost:19093/api/v2/alerts | jq -r '.[] | select(.labels.namespace=="s20-app" or .labels.alertname=="AppDown") | [.labels.alertname, .status.state, .startsAt, .annotations.summary] | @tsv'
EOF
