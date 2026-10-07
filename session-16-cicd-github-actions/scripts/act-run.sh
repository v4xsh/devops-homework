#!/usr/bin/env bash
# Run the Session 16 workflow locally with act (GitHub Actions runner emulator).
#  - jobs run in catthehacker/ubuntu:act-latest containers (same tool set idea as ubuntu-latest)
#  - artifacts go to a local act artifact server
#  - REGISTRY=localhost:5000 -> the push job pushes to my local registry:2 container instead of GHCR
#  - CLUSTER=minikube       -> the deploy job uses a kubeconfig secret for my minikube instead of kind
#  - all secrets are dummy values made up for this run (GITHUB_TOKEN is not passed: act would use it
#    to clone the actions; the GHCR login step is skipped because REGISTRY is not ghcr.io)
# usage: act-run.sh [extra act args...]
set -uo pipefail
STAGE="$HOME/act-stage/session-16-cicd-github-actions/devops-homework"
cd "$STAGE"

# kubeconfig for minikube as seen from a container on the "minikube" docker network
KCFG_B64=$(kubectl config view --minify --flatten --context minikube \
  | sed -E 's#server: https://127.0.0.1:[0-9]+#server: https://192.168.49.2:8443#' | base64 -w0)

act push \
  -W .github/workflows/session16-ci-cd.yml \
  -P ubuntu-latest=catthehacker/ubuntu:act-latest \
  --container-architecture linux/amd64 \
  --pull=false \
  --network minikube \
  --artifact-server-path /tmp/act-artifacts-s16 \
  --var REGISTRY=localhost:5000 \
  --var CLUSTER=minikube \
  -s DEMO_API_KEY=s16-demo-not-a-real-key-7f3a \
  -s KUBE_CONFIG_B64="$KCFG_B64" \
  "$@"
