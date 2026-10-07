#!/usr/bin/env bash
# First IaC scan - BEFORE hardening (the findings below were then fixed, see 07-iac-trivy-config)
P=~/devops-homework/session-21-final-devops-project/final-devops-project
cd "$P"
snap 07a-iac-trivy-config-before-fix --dir "$P" --max-lines 60 <<'XEOF'
trivy config --severity HIGH,CRITICAL --exit-code 1 --quiet . 2>&1 | grep -E '\((kubernetes|helm|terraform|dockerfile)\)$|^Failures|^(KSV|AWS|DS)-[0-9]+'; echo "trivy config exit code: ${PIPESTATUS[0]}"
XEOF
