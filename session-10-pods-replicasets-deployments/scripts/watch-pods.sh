#!/usr/bin/env bash
# watch-pods.sh <namespace> <logfile>
# Streams `kubectl get pods -w --output-watch-events` and prefixes every line with a wall-clock timestamp.
kubectl get pods -n "$1" -w --output-watch-events 2>&1 | while IFS= read -r l; do
  printf '%s  %s\n' "$(date +%H:%M:%S.%3N)" "$l"
done > "$2"
