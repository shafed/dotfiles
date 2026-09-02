#!/usr/bin/env bash
# Runs after nvim exits inside the QAT scratch panel (see
# nvim-scratch-toggle.sh): copies the scratch note to the clipboard, clears the
# scratch file so the next SUPER+N starts blank, and closes the panel.

set -euo pipefail

scratch_file="$HOME/.cache/nvim-scratch.md"
log_file="/tmp/nvim-scratch-quit.log"
panel_pid="$PPID"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file"; }

if [[ ! -s "$scratch_file" ]]; then
  log "empty scratch file, nothing to copy"
  kill "$panel_pid" 2>/dev/null || true
  exit 0
fi

# $(<file) strips ALL trailing newlines (nvim always writes a final one,
# and stray blank lines at the end shouldn't become extra clipboard newlines).
printf '%s' "$(<"$scratch_file")" | wl-copy
log "copied scratch file to clipboard"
: >"$scratch_file"

kill "$panel_pid" 2>/dev/null || true
