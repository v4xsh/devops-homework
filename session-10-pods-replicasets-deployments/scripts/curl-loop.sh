#!/usr/bin/env bash
# curl-loop.sh <namespace> <service-url> <count> <interval-seconds> <grep-pattern>
# Sends <count> requests from the in-cluster curl-client pod and prints "time  <matched version | FAIL>" per request.
kubectl exec -n "$1" curl-client -- sh -c "
for i in \$(seq 1 $3); do
  r=\$(curl -s -m 1 $2 | grep -oE '$5' | head -n1)
  echo \"\$(date +%H:%M:%S) \${r:-FAIL(no response)}\"
  sleep $4
done"
