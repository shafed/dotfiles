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
grep -Fq 'menu_bar_css="\n    ;background: ${bg}\n    ;color: ${fg}' "$conf"
[ "$(wc -l <"$conf")" -lt 100 ]
[ "$(grep -c '^\[Theme\]$' "$conf")" -eq 1 ]
[ "$(grep -c '^\[Options\]$' "$conf")" -eq 1 ]

first="$(sha256sum "$conf" | cut -d' ' -f1)"
HOME="$home" python3 "$ROOT/scripts/copyq-apply-theme.py" >/dev/null
second="$(sha256sum "$conf" | cut -d' ' -f1)"
[ "$first" = "$second" ]

# CopyQ sorts options while saving; replacing a managed value must not move it.
sed -i '/close_on_unfocus=true/d; /\[Options\]/a activate_closes=true\nclose_on_unfocus=false\nclose_on_unfocus_delay_ms=@ByteArray(0)' "$conf"
HOME="$home" python3 "$ROOT/scripts/copyq-apply-theme.py" >/dev/null
sed -n '/^\[Options\]$/,/^\[/p' "$conf" | sed -n '1,4p' | grep -qxF 'close_on_unfocus=true' || {
  echo "managed option moved instead of being replaced in place" >&2
  exit 1
}

echo "copyq theme tests: ok"
