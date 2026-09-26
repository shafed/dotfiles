#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): format the file an agent just wrote with the
# same formatter Neovim would run on it, so an agent's edit and a later save in
# the editor produce the same bytes instead of a reformatting diff.
#
# The mapping mirrors formatters_by_ft in nvim/lua/plugins/conform.lua — keep
# the two in step. tex-fmt is called from Mason's bin, the binary conform uses,
# not from PATH.
#
# Never fails the tool call: a missing formatter or an unformattable file
# leaves the file as the agent wrote it.

set -uo pipefail

file="$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null || true)"
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
  *.md | *.markdown)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write "$file"
    else
      npx --yes prettier@3 --write "$file"
    fi
    ;;
  *.tex)
    "$HOME/.local/share/nvim/mason/bin/tex-fmt" --quiet "$file"
    ;;
esac >/dev/null 2>&1

exit 0
