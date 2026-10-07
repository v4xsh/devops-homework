#!/usr/bin/env bash
# promq.sh '<PromQL>' - run an instant query against the Prometheus HTTP API (port-forwarded to localhost:19090)
# and print one line per series: {labels} => value
PROM=${PROM:-http://localhost:19090}
curl -s -G "$PROM/api/v1/query" --data-urlencode "query=$1" \
  | jq -r 'if .status != "success" then . else
      (.data.result[] | "\(.metric | del(.__name__) | to_entries | map("\(.key)=\"\(.value)\"") | join(", ") | "{" + . + "}")  =>  \(.value[1])") end'
