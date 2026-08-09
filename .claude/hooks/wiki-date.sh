#!/usr/bin/env bash
# PostToolUse hook: after an Edit/Write to a wiki page, set its frontmatter
# `updated:` field to today's date.
#
# Mechanical bookkeeping the agent would otherwise have to remember — and it
# can't reliably know today's date anyway, while `date` can.
#
# Silent by design: prints nothing, always exits 0, so it costs no context
# tokens. Only the `updated:` line inside the leading `---` block is touched;
# a stray `updated:` in body prose or a fenced example (CONVENTIONS.md) is
# left alone.

set -euo pipefail

input="$(cat)"

file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0

repo="$(cd "$(dirname "$0")/../.." && pwd)"

case "$file" in
  "$repo"/wiki/*.md) ;;
  *) exit 0 ;;  # not a wiki page — nothing to do
esac

today="$(date +%F)"

# Rewrite `updated:` only while inside the frontmatter block that opens on
# line 1. A page without that block passes through unchanged.
tmp="$(mktemp)"
awk -v today="$today" '
  NR == 1 && $0 == "---" { fm = 1; print; next }
  fm && /^---[[:space:]]*$/ { fm = 0; print; next }
  fm && /^updated:[[:space:]]/ { print "updated: " today; next }
  { print }
' "$file" >"$tmp"

# Only write back on an actual change, so untouched pages keep their mtime.
if ! cmp -s "$file" "$tmp"; then
  cat "$tmp" >"$file"   # truncate in place, preserving the symlink/inode
fi
rm -f "$tmp"

exit 0
