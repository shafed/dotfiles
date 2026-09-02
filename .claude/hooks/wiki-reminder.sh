#!/usr/bin/env bash
# PostToolUse hook: after an Edit/Write to a tracked config path, remind the
# agent to update the matching wiki page (covers:).
# Reads the tool-call JSON from stdin; emits a reminder on stdout when relevant.
#
# Non-blocking: always exits 0. Only prints when the edited file is a config
# whose changes should be reflected in the wiki — otherwise stays silent.

set -euo pipefail

input="$(cat)"

# Extract the edited file path from the tool input (Edit/Write both use file_path).
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file" ] || exit 0

# Repo root = two levels up from this hook (.claude/hooks/ -> repo).
repo="$(cd "$(dirname "$0")/../.." && pwd)"

# Make the path relative to the repo, if it's inside it.
case "$file" in
"$repo"/*) rel="${file#"$repo"/}" ;;
*) exit 0 ;; # edit outside the repo — nothing to do
esac

# Never nag about edits to the wiki itself or agent-instruction files.
case "$rel" in
wiki/* | AGENTS.md | CLAUDE.md | .claude/*) exit 0 ;;
esac

# Only react to config areas that have wiki coverage.
case "$rel" in
kanata/* | hypr/* | scripts/* | zsh/* | kitty/* | nvim/* | yazi/* | darkman/*) ;;
*) exit 0 ;;
esac

# Find wiki page(s) whose `covers:` lists a path under the same top dir as rel.
# Skip meta pages (index/CONVENTIONS) — they mention `covers:` as prose.
top="${rel%%/*}"
match="$(for page in "$repo"/wiki/*.md; do
  case "$(basename "$page")" in index.md | CONVENTIONS.md) continue ;; esac
  # match a covers: list entry that starts with "<top>/"
  if grep -qE "^[[:space:]]*-[[:space:]]*${top}/" "$page" 2>/dev/null; then
    basename "$page" .md
  fi
done | sort -u | paste -sd, -)"

msg="📝 wiki: изменён '${rel}'. Обнови соответствующую страницу wiki (covers: ${top}/…)${match:+ — вероятно [[${match}]]}. См. AGENTS.md."

# Emit as PostToolUse additionalContext so the reminder is injected into the
# model's context (a bare stdout line is not reliably surfaced to the model).
jq -n --arg ctx "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
exit 0
