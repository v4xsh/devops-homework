#!/usr/bin/env bash
# Session 10 - Task 2: Pod lifecycle lab (namespace s10-lifecycle), all output captured with snap
set -u
D=~/devops-homework/session-10-pods-replicasets-deployments
cd "$D"
kubectl delete ns s10-lifecycle --ignore-not-found --wait=true >/dev/null 2>&1
kubectl create ns s10-lifecycle >/dev/null
# background timestamped watch of the whole lab (shown at the end)
bash scripts/watch-pods.sh s10-lifecycle outputs/lifecycle-watch.log &

snap 20-pod-running --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/01-running.yaml
kubectl wait -n s10-lifecycle --for=condition=Ready pod/lifecycle-running --timeout=90s
kubectl get pod lifecycle-running -n s10-lifecycle -o wide
kubectl get pod lifecycle-running -n s10-lifecycle -o jsonpath='phase={.status.phase}{"\n"}{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
kubectl describe pod lifecycle-running -n s10-lifecycle | sed -n '/^Events:/,$p'
EOF

snap 21-pod-pending --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/02-pending.yaml
sleep 5; kubectl get pod lifecycle-pending -n s10-lifecycle -o wide
kubectl get pod lifecycle-pending -n s10-lifecycle -o jsonpath='phase={.status.phase}  PodScheduled={.status.conditions[0].status} reason={.status.conditions[0].reason}{"\n"}'
kubectl describe pod lifecycle-pending -n s10-lifecycle | sed -n '/^    Requests:/,/^    Environment/p;/^Events:/,$p'
kubectl get node minikube -o jsonpath='node allocatable memory = {.status.allocatable.memory}{"\n"}'
EOF

snap 22-pod-succeeded --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/03-succeeded.yaml
sleep 2; kubectl get pod lifecycle-succeeded -n s10-lifecycle
kubectl wait -n s10-lifecycle --for=jsonpath='{.status.phase}'=Succeeded pod/lifecycle-succeeded --timeout=90s
kubectl get pod lifecycle-succeeded -n s10-lifecycle
kubectl logs lifecycle-succeeded -n s10-lifecycle
kubectl describe pod lifecycle-succeeded -n s10-lifecycle | sed -n '/^    State:/,/^    Ready:/p;/^Events:/,$p'
EOF

snap 23-pod-failed --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/04-failed.yaml
kubectl wait -n s10-lifecycle --for=jsonpath='{.status.phase}'=Failed pod/lifecycle-failed --timeout=90s
kubectl get pod lifecycle-failed -n s10-lifecycle
kubectl logs lifecycle-failed -n s10-lifecycle
kubectl get pod lifecycle-failed -n s10-lifecycle -o jsonpath='phase={.status.phase} restartPolicy={.spec.restartPolicy} exitCode={.status.containerStatuses[0].state.terminated.exitCode} reason={.status.containerStatuses[0].state.terminated.reason}{"\n"}'
kubectl describe pod lifecycle-failed -n s10-lifecycle | sed -n '/^Events:/,$p'
EOF

snap 24-pod-crashloopbackoff --dir "$D" --max-lines 90 <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/05-crashloopbackoff.yaml
for i in $(seq 1 100); do echo "$(date +%T) $(kubectl get pod lifecycle-crashloop -n s10-lifecycle --no-headers | awk '{print $3, "restarts="$4}')"; sleep 1; done | uniq -f1
kubectl get pod lifecycle-crashloop -n s10-lifecycle
kubectl logs lifecycle-crashloop -n s10-lifecycle
kubectl get pod lifecycle-crashloop -n s10-lifecycle -o jsonpath='restartPolicy={.spec.restartPolicy} restartCount={.status.containerStatuses[0].restartCount} waiting={.status.containerStatuses[0].state.waiting.reason} lastExit={.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}'
kubectl describe pod lifecycle-crashloop -n s10-lifecycle | sed -n '/^Events:/,$p'
EOF

snap 25-pod-imagepullbackoff --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/06-imagepullbackoff.yaml
sleep 20; kubectl get pod lifecycle-image-error -n s10-lifecycle
kubectl get pod lifecycle-image-error -n s10-lifecycle -o jsonpath='phase={.status.phase} waiting={.status.containerStatuses[0].state.waiting.reason}{"\n"}'
kubectl describe pod lifecycle-image-error -n s10-lifecycle | sed -n '/^Events:/,$p'
EOF

snap 26-probe-readiness --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/07-readiness.yaml
sleep 3; kubectl get pod lifecycle-readiness -n s10-lifecycle
kubectl get pod lifecycle-readiness -n s10-lifecycle -o jsonpath='phase={.status.phase} {range .status.conditions[*]}{.type}={.status} {end}{"\n"}'
sleep 7; kubectl get pod lifecycle-readiness -n s10-lifecycle
kubectl get pod lifecycle-readiness -n s10-lifecycle -o jsonpath='phase={.status.phase} {range .status.conditions[*]}{.type}={.status} {end}{"\n"}'
kubectl describe pod lifecycle-readiness -n s10-lifecycle | grep -E 'Readiness:|Ready:'
EOF

snap 27-probe-liveness --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/08-liveness.yaml
sleep 15; kubectl get pod lifecycle-liveness -n s10-lifecycle
kubectl wait -n s10-lifecycle --for=jsonpath='{.status.containerStatuses[0].restartCount}'=1 pod/lifecycle-liveness --timeout=180s
kubectl get pod lifecycle-liveness -n s10-lifecycle
kubectl logs lifecycle-liveness -n s10-lifecycle --previous
kubectl describe pod lifecycle-liveness -n s10-lifecycle | grep -E 'Liveness:|Restart Count:|Last State:|Reason:|Exit Code:'
kubectl describe pod lifecycle-liveness -n s10-lifecycle | sed -n '/^Events:/,$p'
EOF

snap 28-probe-startup --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/09-startup.yaml
sleep 15; kubectl get pod lifecycle-startup -n s10-lifecycle
kubectl get pod lifecycle-startup -n s10-lifecycle -o jsonpath='started={.status.containerStatuses[0].started} ready={.status.containerStatuses[0].ready}{"\n"}'
sleep 25; kubectl get pod lifecycle-startup -n s10-lifecycle
kubectl get pod lifecycle-startup -n s10-lifecycle -o jsonpath='started={.status.containerStatuses[0].started} ready={.status.containerStatuses[0].ready} restarts={.status.containerStatuses[0].restartCount}{"\n"}'
kubectl logs lifecycle-startup -n s10-lifecycle
kubectl describe pod lifecycle-startup -n s10-lifecycle | sed -n '/Startup:/p;/^Events:/,$p'
EOF

snap 29-init-container --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/10-init-container.yaml
sleep 4; kubectl get pod lifecycle-init -n s10-lifecycle
kubectl wait -n s10-lifecycle --for=condition=Ready pod/lifecycle-init --timeout=90s
kubectl get pod lifecycle-init -n s10-lifecycle
kubectl logs lifecycle-init -n s10-lifecycle -c setup
kubectl get pod lifecycle-init -n s10-lifecycle -o jsonpath='init: {.status.initContainerStatuses[0].name} -> {.status.initContainerStatuses[0].state.terminated.reason} (exit {.status.initContainerStatuses[0].state.terminated.exitCode}){"\n"}'
kubectl describe pod lifecycle-init -n s10-lifecycle | sed -n '/^Events:/,$p'
EOF

snap 30-multi-container --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/11-multi-container.yaml
kubectl wait -n s10-lifecycle --for=condition=Ready pod/lifecycle-multi-container --timeout=90s
kubectl get pod lifecycle-multi-container -n s10-lifecycle
kubectl get pod lifecycle-multi-container -n s10-lifecycle -o jsonpath='{range .status.containerStatuses[*]}{.name}: ready={.ready} image={.image}{"\n"}{end}'
sleep 12; kubectl logs lifecycle-multi-container -n s10-lifecycle -c sidecar
kubectl exec lifecycle-multi-container -n s10-lifecycle -c sidecar -- wget -qO- http://localhost:80 | grep -o '<title>.*</title>'
kubectl describe pod lifecycle-multi-container -n s10-lifecycle | sed -n '/^Events:/,$p'
EOF

snap 31-graceful-termination --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/12-termination.yaml
kubectl wait -n s10-lifecycle --for=condition=Ready pod/lifecycle-termination --timeout=90s
kubectl get pod lifecycle-termination -n s10-lifecycle -o jsonpath='terminationGracePeriodSeconds={.spec.terminationGracePeriodSeconds}{"\n"}'
date +%T; kubectl delete pod lifecycle-termination -n s10-lifecycle --wait=false
sleep 3; kubectl get pod lifecycle-termination -n s10-lifecycle
kubectl logs lifecycle-termination -n s10-lifecycle
kubectl wait -n s10-lifecycle --for=delete pod/lifecycle-termination --timeout=60s; date +%T
kubectl get events -n s10-lifecycle --field-selector involvedObject.name=lifecycle-termination
EOF

snap 32-replicaset-self-healing --dir "$D" <<'EOF'
kubectl apply -n s10-lifecycle -f task2-pod-lifecycle/13-replicaset-self-healing.yaml
kubectl wait -n s10-lifecycle --for=condition=Ready pod -l app=yatri-backend --timeout=90s >/dev/null; kubectl get rs,pods -n s10-lifecycle -l app=yatri-backend
VICTIM=$(kubectl get pods -n s10-lifecycle -l app=yatri-backend -o jsonpath='{.items[0].metadata.name}'); echo "deleting $VICTIM"; kubectl delete pod $VICTIM -n s10-lifecycle
sleep 3; kubectl get pods -n s10-lifecycle -l app=yatri-backend
kubectl describe rs yatri-backend-rs -n s10-lifecycle | sed -n '/^Events:/,$p'
kubectl scale rs yatri-backend-rs -n s10-lifecycle --replicas=5; sleep 4; kubectl get rs yatri-backend-rs -n s10-lifecycle
kubectl get pod -n s10-lifecycle -l app=yatri-backend -o custom-columns=POD:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name
EOF

snap 33-lifecycle-summary --dir "$D" --max-lines 60 <<'EOF'
kubectl get pods -n s10-lifecycle -o custom-columns='POD:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,WAITING:.status.containerStatuses[*].state.waiting.reason,TERMINATED:.status.containerStatuses[*].state.terminated.reason' | grep -v yatri
kubectl get events -n s10-lifecycle --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 15
EOF

pkill -f 'get pods -n s10-lifecycle -w'
