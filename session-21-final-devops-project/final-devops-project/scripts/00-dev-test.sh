#!/usr/bin/env bash
# quick dev loop (not snapped)
set -e
P=~/devops-homework/session-21-final-devops-project/final-devops-project
python3 -m venv ~/build/s21-venv 2>/dev/null || true
~/build/s21-venv/bin/pip install -q -r $P/application/backend/requirements-dev.txt
cd $P/application/backend
~/build/s21-venv/bin/ruff check . && ~/build/s21-venv/bin/python -m pytest -q -p no:cacheprovider 2>&1 | tail -15
