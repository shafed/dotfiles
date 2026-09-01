#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
conf="$home/.config/copyq/copyq.conf"
mkdir -p "$(dirname "$conf")"
cat >"$conf" <<'EOF'
[General]
keep_me=true
EOF

HOME="$home" python3 "$ROOT/scripts/copyq-apply-theme.py" >/dev/null

grep -q '^\[Theme\]$' "$conf"
grep -q '^\[Options\]$' "$conf"
grep -q '^close_on_unfocus=true$' "$conf"
grep -q '^keep_me=true$' "$conf"
[ "$(grep -c '^\[Theme\]$' "$conf")" -eq 1 ]
[ "$(grep -c '^\[Options\]$' "$conf")" -eq 1 ]

first="$(sha256sum "$conf" | cut -d' ' -f1)"
HOME="$home" python3 "$ROOT/scripts/copyq-apply-theme.py" >/dev/null
second="$(sha256sum "$conf" | cut -d' ' -f1)"
[ "$first" = "$second" ]

echo "copyq theme tests: ok"
