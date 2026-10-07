for i in nginx:1.24-alpine nginx:1.25-alpine nginx:1.27 busybox:1.36 curlimages/curl:8.10.1 gcr.io/google-samples/kubernetes-bootcamp:v1 docker.io/jocatalin/kubernetes-bootcamp:v2 python:3.11-alpine; do
  minikube ssh -- sudo crictl pull $i 2>&1 | tail -1
done
