#!/usr/bin/env bash
set -euo pipefail

root="$HOME/github/dotfiles/quickshell"
python3 "$root/layout-watch.py" &
exec quickshell -p "$root"
