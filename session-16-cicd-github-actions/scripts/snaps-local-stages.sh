#!/usr/bin/env bash
# Run each pipeline stage's commands directly on my machine and capture them with `snap`.
set -euo pipefail
S=~/devops-homework/session-16-cicd-github-actions
export PATH="$HOME/venvs/s1617/bin:$PATH"
cd "$S"

snap 01-lint-and-unit-tests --dir "$S" <<'EOF'
python --version
flake8 app tests --count --statistics
pytest -v -p no:cacheprovider --cov=app --cov-report=term-missing --cov-report=xml:reports/coverage.xml --junitxml=reports/junit.xml --cov-fail-under=90
ls -l reports/
EOF

snap 02-docker-build-and-run --dir "$S" --max-lines 60 <<'EOF'
GIT_SHA=local01
docker build --progress=plain --build-arg GIT_SHA=$GIT_SHA -t s16-calculator-api:$GIT_SHA . 2>&1 | tail -n 14
docker image ls s16-calculator-api
docker run -d --rm --name s16-calc -p 8100:8000 s16-calculator-api:$GIT_SHA
sleep 3
curl -s localhost:8100/health; echo
curl -s localhost:8100/version; echo
curl -s "localhost:8100/api/add?a=2&b=3"; echo
curl -s -X POST localhost:8100/api/calculate -H 'Content-Type: application/json' -d '{"operation":"divide","a":1,"b":0}'; echo
docker exec s16-calc id
docker rm -f s16-calc
EOF
rm -rf reports .coverage
