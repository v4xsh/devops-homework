#!/usr/bin/env bash
# Session 12 / Task 1 - ConfigMaps: create 3 ways, inject 3 ways, verify inside the container
set -u
S=~/devops-homework/session-12-ingress-configmaps-secrets
D=$S/01-configmap
cd $D

snap 01-configmap-create --dir $S --max-lines 80 <<'EOF'
kubectl apply -f ../00-namespace/namespaces.yaml
echo "--- method 1: from literals"
kubectl create configmap app-literal-config -n s12 --from-literal=APP_COLOR=blue --from-literal=APP_MODE=demo --from-literal=FEATURE_FLAGS=search,booking
echo "--- method 2: from files (key = file name, value = file content)"
kubectl create configmap app-file-config -n s12 --from-file=app.properties --from-file=nginx-extra.conf
echo "--- method 3: declarative YAML"
kubectl apply -f app-config.yaml
kubectl get configmaps -n s12
EOF

snap 02-configmap-inspect --dir $S --max-lines 90 <<'EOF'
kubectl describe configmap app-literal-config -n s12
kubectl get configmap app-file-config -n s12 -o yaml
kubectl get configmap yatri-app-config -n s12 -o jsonpath='{.data.settings\.json}'
EOF

snap 03-configmap-pod --dir $S <<'EOF'
kubectl apply -f pod-using-configmaps.yaml
kubectl wait --for=condition=Ready pod/config-demo -n s12 --timeout=120s
kubectl get pod config-demo -n s12
kubectl logs config-demo -n s12
kubectl describe pod config-demo -n s12 | sed -n '/Environment Variables from:/,/Mounts:/p'
EOF

snap 04-configmap-verify-inside --dir $S --max-lines 80 <<'EOF'
echo "--- env (single keys via configMapKeyRef)"
kubectl exec -n s12 config-demo -- sh -c 'echo APP_ENV=$APP_ENV; echo APP_LOG_LEVEL=$APP_LOG_LEVEL; echo APP_COLOR=$APP_COLOR'
echo "--- envFrom (all keys of app-literal-config, prefixed LIT_)"
kubectl exec -n s12 config-demo -- sh -c 'env | grep ^LIT_ | sort'
echo "--- volume mounts (each key is a file)"
kubectl exec -n s12 config-demo -- ls -l /etc/yatri /etc/app
kubectl exec -n s12 config-demo -- cat /etc/yatri/settings.json
kubectl exec -n s12 config-demo -- cat /etc/yatri/log_level; echo
kubectl exec -n s12 config-demo -- cat /etc/app/app.properties
EOF

snap 05-configmap-live-update --dir $S <<'EOF'
echo "--- update the ConfigMap: mounted files refresh automatically, env vars do NOT"
kubectl patch configmap yatri-app-config -n s12 --type merge -p '{"data":{"LOG_LEVEL":"DEBUG"}}'
for i in $(seq 1 30); do v=$(kubectl exec -n s12 config-demo -- cat /etc/yatri/log_level); [ "$v" = "DEBUG" ] && break; sleep 3; done; echo "waited ~$((i*3))s for kubelet sync"
kubectl exec -n s12 config-demo -- cat /etc/yatri/log_level; echo
kubectl exec -n s12 config-demo -- sh -c 'echo "env still says APP_LOG_LEVEL=$APP_LOG_LEVEL (needs a pod restart)"'
EOF
