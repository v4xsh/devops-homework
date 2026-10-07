#!/usr/bin/env bash
# Run the Session 17 DevSecOps workflow locally with act (GitHub Actions runner emulator).
#  - jobs run in catthehacker/ubuntu:act-latest containers
#  - REGISTRY=localhost:5000 -> push job pushes to my local registry:2 container instead of GHCR
#  - CLUSTER=minikube       -> deploy job uses a kubeconfig secret for my minikube instead of kind
#  - secrets are dummy values made up for this run; GITHUB_TOKEN is not passed (act would use it to
#    clone the actions) and the GHCR login step is skipped because REGISTRY is not ghcr.io
# usage: act-run.sh <event: push> [extra act args...]
set -uo pipefail
STAGE="$HOME/act-stage/session-17-devsecops/devops-homework"
cd "$STAGE"

KCFG_B64=$(kubectl config view --minify --flatten --context minikube \
  | sed -E 's#server: https://127.0.0.1:[0-9]+#server: https://192.168.49.2:8443#' | base64 -w0)

act "${1:-push}" \
  -W .github/workflows/session17-devsecops.yml \
  -P ubuntu-latest=catthehacker/ubuntu:act-latest \
  --container-architecture linux/amd64 \
  --pull=false \
  --network minikube \
  --artifact-server-path /tmp/act-artifacts-s17 \
  --var REGISTRY=localhost:5000 \
  --var CLUSTER=minikube \
  -s APP_SECRET_KEY=s17-demo-flask-key-not-real \
  -s KUBE_CONFIG_B64="$KCFG_B64" \
  "${@:2}"
