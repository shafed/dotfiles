#!/usr/bin/env bash
set -euo pipefail
root="$HOME/github/dotfiles/quickshell"
runtime="$(python3 "$root/prepare.py")"
exec quickshell -p "$runtime"
