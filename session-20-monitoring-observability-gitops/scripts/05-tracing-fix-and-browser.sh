#!/usr/bin/env bash
# Session 20 / Task 2 - fix trace exclusion regex (v1.1.0), show end-to-end traces in Jaeger, then real browser captures.
set -u
S=~/devops-homework/session-20-monitoring-observability-gitops
cd "$S"
B="$HOME/venv-s21/bin/python $S/scripts/browser_shot.py"

snap 14a-tracing-fix-v1.1.0 --dir "$S" <<'XEOF'
grep -n 'excluded_urls' task1-monitoring/sample-app/app.py
cd task1-monitoring/sample-app && docker build -q -t s20-metrics-app:1.1.0 . && minikube image load s20-metrics-app:1.1.0 && cd "$OLDPWD"
kubectl apply -f task1-monitoring/k8s/app.yaml
kubectl rollout status deploy/s20-metrics-app -n s20-app --timeout=180s
kubectl get pods -n s20-app -l app=s20-metrics-app -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready
XEOF

sleep 40
snap 14-jaeger-traces --dir "$S" <<'XEOF'
kubectl get deploy s20-metrics-app -n s20-app -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}'
curl -s localhost:16686/api/services | jq -c .
curl -s localhost:16686/api/services/s20-metrics-app/operations | jq -c .data
curl -s 'localhost:16686/api/traces?service=s20-metrics-app&operation=GET%20%2Fwork&limit=1&lookback=5m' | jq -r '.data[0] | "traceID=\(.traceID)  spans=\(.spans|length)", (.spans[] | "  span=\(.operationName)  duration=\(.duration)us  parent=\(.references[0].spanID // "root")")'
curl -s 'localhost:16686/api/traces?service=s20-metrics-app&operation=GET%20%2Ferror&limit=1&lookback=5m' | jq -r '.data[0].spans[0] | "\(.operationName): " + ([.tags[] | select(.key=="http.response.status_code" or .key=="http.status_code" or .key=="error" or .key=="otel.status_code") | "\(.key)=\(.value)"] | join(" "))'
XEOF

TRACE=$(curl -s 'localhost:16686/api/traces?service=s20-metrics-app&operation=GET%20%2Fwork&limit=1&lookback=5m' | jq -r '.data[0].traceID')
$B "http://localhost:16686/search?service=s20-metrics-app&operation=GET%20%2Fwork&limit=20&lookback=15m" screenshots/browser/jaeger-search.png --wait-ms 4000
$B "http://localhost:16686/trace/$TRACE" screenshots/browser/jaeger-trace-detail.png --wait-ms 4000
$B "http://localhost:19090/targets?search=s20" screenshots/browser/prometheus-targets.png --wait-ms 3000
$B "http://localhost:19090/query?g0.expr=sum%20by%20(endpoint%2C%20status)%20(rate(app_requests_total%7Bnamespace%3D%22s20-app%22%7D%5B1m%5D))&g0.tab=graph&g0.range_input=1h" screenshots/browser/prometheus-graph-request-rate.png --wait-ms 4000
$B "http://localhost:19090/query?g0.expr=sum%20by%20(pod)%20(rate(container_cpu_usage_seconds_total%7Bnamespace%3D%22s20-app%22%2Ccontainer!%3D%22%22%7D%5B2m%5D))&g0.tab=graph&g0.range_input=1h" screenshots/browser/prometheus-graph-cpu.png --wait-ms 4000
$B "http://localhost:13000/d/s20-metrics-app?orgId=1&from=now-1h&to=now" screenshots/browser/grafana-s20-dashboard.png --grafana-login admin:s20-grafana-admin --height 1150 --wait-ms 8000
$B "http://localhost:13000/d/85a562078cdf77779eaa1add43ccec1e?orgId=1&var-datasource=prometheus&var-namespace=s20-app&from=now-1h&to=now" screenshots/browser/grafana-k8s-namespace-cpu-memory.png --grafana-login admin:s20-grafana-admin --height 1150 --wait-ms 8000
