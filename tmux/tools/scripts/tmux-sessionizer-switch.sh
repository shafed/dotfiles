#!/usr/bin/env bash
# tmux-sessionizer-switch
#
# Fuzzy switcher over EXISTING tmux sessions only (no zoxide, no directories).
# Companion to tmux-sessionizer. Bind this to a separate tmux hotkey for
# quick jumps between already-open sessions.
#
# Usage:
#   tmux-sessionizer-switch          # switch to selected session
#   tmux-sessionizer-switch -k       # kill selected session(s), multi-select with TAB

set -euo pipefail

if ! command -v tmux &>/dev/null; then
  echo "tmux is not installed"
  exit 1
fi

if ! command -v fzf &>/dev/null; then
  echo "fzf is not installed"
  exit 1
fi

mode="switch"
case "${1:-}" in
-k | --kill) mode="kill" ;;
-h | --help)
  cat <<'EOF'
Usage: tmux-sessionizer-switch [OPTIONS]

Fuzzy switcher over existing tmux sessions.

Options:
  (none)         Switch to selected session
  -k, --kill     Kill selected session(s). TAB to multi-select.
  -h, --help     Show this help
EOF
  exit 0
  ;;
"") ;;
*)
  echo "unknown option: $1"
  exit 1
  ;;
esac

# Grab all sessions. In switch mode, exclude the current one (can't switch to self).
if ! tmux list-sessions &>/dev/null; then
  echo "no tmux sessions running"
  exit 1
fi

if [[ -n "${TMUX:-}" && "$mode" == "switch" ]]; then
  current=$(tmux display-message -p '#S')
  sessions=$(tmux list-sessions -F '#{session_name}' | grep -vFx "$current" || true)
else
  sessions=$(tmux list-sessions -F '#{session_name}')
fi

if [[ -z "$sessions" ]]; then
  if [[ "$mode" == "switch" ]]; then
    echo "no other sessions to switch to"
  else
    echo "no sessions"
  fi
  exit 0
fi

# Preview: capture the last 50 lines of the session's active pane
preview_cmd='tmux capture-pane -ep -t {} 2>/dev/null | tail -50'

if [[ "$mode" == "kill" ]]; then
  selected=$(
    echo "$sessions" | fzf \
      --multi \
      --layout=reverse \
      --preview "$preview_cmd" \
      --preview-window=right:55%:wrap \
      --prompt='kill> ' \
      --header='TAB: mark | ENTER: kill marked | CTRL-C: cancel' \
      --bind='ctrl-a:toggle-all'
  )

  [[ -z "$selected" ]] && exit 0

  while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    tmux kill-session -t "$s" && echo "killed: $s"
  done <<<"$selected"
  exit 0
fi

# switch mode
selected=$(echo "$sessions" | fzf \
  --layout=reverse \
  --preview "$preview_cmd" \
  --preview-window=right:55%:wrap \
  --prompt='session> ' \
  --header='ENTER: switch | CTRL-C: cancel')

[[ -z "$selected" ]] && exit 0

if [[ -z "${TMUX:-}" ]]; then
  tmux attach-session -t "$selected"
else
  tmux switch-client -t "$selected"
fi
