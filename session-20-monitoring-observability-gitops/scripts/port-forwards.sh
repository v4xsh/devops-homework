#!/usr/bin/env bash
# keep port-forwards alive (restart loop)
pf() { while true; do kubectl port-forward -n "$1" "$2" "$3" >/dev/null 2>&1; sleep 2; done & }
pkill -f "kubectl port-forward -n monitoring" ; pkill -f "kubectl port-forward -n s20-app"; pkill -f "kubectl port-forward -n argocd"
pf monitoring svc/kps-prometheus 19090:9090
pf monitoring svc/kps-alertmanager 19093:9093
pf monitoring svc/kps-grafana 13000:80
pf s20-app svc/jaeger 16686:16686
pf argocd svc/argocd-server 18443:443
wait
