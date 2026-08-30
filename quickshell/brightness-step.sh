#!/usr/bin/env bash
set -euo pipefail

step="${1:?brightness step required, e.g. 5%+ or 5%-}"
root="$HOME/github/dotfiles/quickshell"

brightnessctl -e4 -n2 set "$step" >/dev/null
value="$(brightnessctl -m | awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4; exit }')"

if [[ "$value" =~ ^[0-9]+$ ]]; then
  bash "$root/dots-shell" showOsd SUN "${value}%" "$value" >/dev/null 2>&1 || true
fi
