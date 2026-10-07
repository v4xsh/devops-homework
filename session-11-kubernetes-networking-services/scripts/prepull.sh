#!/usr/bin/env bash
# Pre-pull lab images into the minikube node so pods start quickly
for i in nginx:1.25-alpine curlimages/curl:8.5.0 registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 hashicorp/http-echo:1.0 busybox:1.36 postgres:16-alpine python:3.11-alpine3.19; do
  minikube ssh -- sudo crictl pull "$i"
done
