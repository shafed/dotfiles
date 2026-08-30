#!/usr/bin/env bash
set -euo pipefail
root="$HOME/github/dotfiles/quickshell"
runtime="$(python3 "$root/prepare.py")"
python3 "$root/realtime.py" "$runtime/shell.qml"
exec quickshell -p "$runtime"
