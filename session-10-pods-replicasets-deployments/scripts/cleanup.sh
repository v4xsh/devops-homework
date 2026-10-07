#!/usr/bin/env bash
# Remove the lab namespaces (YAML + outputs stay in the repo)
pgrep -af 'kubectl get pods -n s10-' || echo "no leftover watch processes"
kubectl delete ns s10-rolling s10-bluegreen s10-canary s10-recreate s10-lifecycle --ignore-not-found --wait=false
