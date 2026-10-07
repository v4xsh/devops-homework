#!/usr/bin/env bash
# Pre-pull the images used in this session into the minikube node (speeds up rollouts)
for i in nginx:1.16.0 nginx:1.25-alpine nginx:1.26-alpine nginx:1.27-alpine busybox:1.36; do
  minikube image pull "$i"
done
