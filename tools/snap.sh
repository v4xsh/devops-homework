#!/usr/bin/env bash
# snap.sh - run real commands and save them as a terminal screenshot + text log.
#
# Usage:
#   snap <name> [--dir <session-dir>] [--max-lines N] [--cols N] <<'EOF'
#   kubectl get pods
#   kubectl describe pod web
#   EOF
#
# Each stdin line is executed in this shell (so `cd` and variables persist).
# Output:  <session-dir>/screenshots/<name>.png   (macOS-style terminal image)
#          <session-dir>/outputs/<name>.txt       (plain text of the same run)

set -u
TOOLS="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
NAME="$1"; shift
DIR="$PWD"; MAX=70; COLS=150
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --max-lines) MAX="$2"; shift 2 ;;
    --cols) COLS="$2"; shift 2 ;;
    *) shift ;;
  esac
done
DIR="$(readlink -f "$DIR")"
mkdir -p "$DIR/screenshots" "$DIR/outputs"
CAP="$(mktemp)"
TXT="$DIR/outputs/$NAME.txt"
: > "$TXT"
export COLUMNS=$COLS TERM=xterm-256color

__short() { local p="${PWD/#$HOME/\~}"; p="${p/#\/mnt\/c\/Users\/Vansh\/OneDrive\/Desktop\/dev-ops\/devops-homework/\~/devops-homework}"; echo "$p"; }

mapfile -t __cmds
for __cmd in "${__cmds[@]}"; do
  [ -z "$__cmd" ] && continue
  __cwd="$(__short)"
  printf '\x1e$ %s\x1f%s\n' "$__cwd" "$__cmd" >> "$CAP"
  printf '%s$ %s\n' "$__cwd" "$__cmd" >> "$TXT"
  eval "$__cmd" < /dev/null > "$CAP.out" 2>&1
  cat "$CAP.out" >> "$TXT"
  cat "$CAP.out" >> "$CAP"
done

python3 "$TOOLS/termshot.py" "$CAP" "$DIR/screenshots/$NAME.png" \
  --max-lines "$MAX" --cols "$COLS" --cwd "$(__short)" \
  --title "vansh@Vansh-G15 — Vansh Dobhal (Roll No. 10099) — $(date '+%d %b %Y %H:%M')"
rm -f "$CAP" "$CAP.out"
echo "[snap] $DIR/screenshots/$NAME.png"
