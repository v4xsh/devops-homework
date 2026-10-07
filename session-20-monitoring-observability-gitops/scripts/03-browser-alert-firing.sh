#!/usr/bin/env bash
# Real headless-Chromium captures of the Prometheus / Alertmanager UIs while AppDown is firing.
S=~/devops-homework/session-20-monitoring-observability-gitops
B="$HOME/venv-s21/bin/python $S/scripts/browser_shot.py"
mkdir -p $S/screenshots/browser
$B "http://localhost:19090/alerts?search=AppDown" $S/screenshots/browser/prometheus-alert-appdown-firing.png --wait-ms 3000 --click-text "AppDown"
$B "http://localhost:19093/#/alerts" $S/screenshots/browser/alertmanager-appdown-active.png --wait-ms 3000
