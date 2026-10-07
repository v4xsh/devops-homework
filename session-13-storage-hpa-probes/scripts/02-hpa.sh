#!/usr/bin/env bash
# Task 2: HPA demo. Takes ~15 minutes because it waits for real scaling events.
D=~/devops-homework/session-13-storage-hpa-probes/02-hpa
cd $D
kubectl apply -f ../01-kubernetes-volumes/namespace.yaml >/dev/null
snap 01-deploy-app --dir $D <<'EOF'
kubectl apply -f php-apache.yaml
kubectl rollout status deployment/php-apache -n s13 --timeout=120s
kubectl get deploy,svc,pods -n s13 -l app=php-apache -o wide
kubectl get deploy php-apache -n s13 -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl exec deploy/php-apache -n s13 -- curl -s localhost
EOF
snap 02-create-hpa --dir $D <<'EOF'
kubectl apply -f hpa.yml
sleep 60
kubectl get hpa -n s13
kubectl top pods -n s13
kubectl describe hpa php-apache-hpa -n s13
EOF
snap 03-start-load-generator --dir $D <<'EOF'
kubectl apply -f load-generator.yaml
kubectl rollout status deployment/load-generator -n s13 --timeout=120s
sleep 5
kubectl logs deploy/load-generator -n s13
kubectl get pods -n s13 -o wide
EOF
for i in 1 2 3; do
snap 04-load-t$i --dir $D <<'EOF'
sleep 45
date '+%H:%M:%S'
kubectl get hpa -n s13
kubectl top pods -n s13
kubectl get pods -n s13 -l app=php-apache
EOF
done
snap 05-increase-load --dir $D <<'EOF'
kubectl scale deployment/load-generator -n s13 --replicas=3
kubectl rollout status deployment/load-generator -n s13 --timeout=120s
kubectl get pods -n s13 -l app=load-generator
EOF
for i in 4 5 6; do
snap 04-load-t$i --dir $D <<'EOF'
sleep 45
date '+%H:%M:%S'
kubectl get hpa -n s13
kubectl top pods -n s13
kubectl get pods -n s13 -l app=php-apache
EOF
done
snap 06-describe-hpa-scaled-up --dir $D --max-lines 80 <<'EOF'
kubectl describe hpa php-apache-hpa -n s13
kubectl get deploy php-apache -n s13
kubectl get events -n s13 --field-selector involvedObject.kind=HorizontalPodAutoscaler --sort-by=.lastTimestamp
EOF
snap 07-remove-load --dir $D <<'EOF'
kubectl delete -f load-generator.yaml
date '+%H:%M:%S'
kubectl get hpa -n s13
kubectl top pods -n s13
EOF
for i in 1 2 3 4; do
snap 08-scale-down-t$i --dir $D <<'EOF'
sleep 50
date '+%H:%M:%S'
kubectl get hpa -n s13
kubectl top pods -n s13
kubectl get pods -n s13 -l app=php-apache
EOF
done
snap 09-describe-hpa-scaled-down --dir $D --max-lines 80 <<'EOF'
kubectl get hpa -n s13
kubectl get pods -n s13
kubectl describe hpa php-apache-hpa -n s13
EOF
