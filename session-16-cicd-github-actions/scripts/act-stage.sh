#!/usr/bin/env bash
# Prepare a throw-away git checkout for running a workflow locally with `act`.
#
# act needs a git repository to fill in github.sha / github.ref / github.repository_owner.
# The homework folder is not committed yet (the student pushes it later), so this script copies
# the repo-root workflow file + the session folder into ~/act-stage/<session>/devops-homework,
# makes a single local commit on `main` there and adds the future GitHub remote (nothing is pushed).
#
# usage: act-stage.sh <session-folder> <workflow-file-name>
set -euo pipefail
SESSION="${1:?session folder, e.g. session-16-cicd-github-actions}"
WORKFLOW="${2:?workflow file name, e.g. session16-ci-cd.yml}"
SRC="$HOME/devops-homework"
STAGE="$HOME/act-stage/$SESSION/devops-homework"

rm -rf "$STAGE"
mkdir -p "$STAGE/.github/workflows"
rsync -a \
  --exclude screenshots --exclude outputs --exclude reports --exclude .coverage \
  --exclude __pycache__ --exclude .pytest_cache --exclude image.tar.gz \
  "$SRC/$SESSION" "$STAGE/"
cp "$SRC/.github/workflows/$WORKFLOW" "$STAGE/.github/workflows/"

cd "$STAGE"
git init -q -b main
git remote add origin https://github.com/v4xsh/devops-homework.git
git add -A
git -c user.name="Vansh Dobhal" -c user.email="vanshdobhal11@gmail.com" \
  commit -q -m "$SESSION: local act run"
echo "staged at $STAGE  (commit $(git rev-parse --short HEAD) on $(git branch --show-current))"
