#!/usr/bin/env bash
# Toggle a floating kitty+nvim scratchpad for jotting a note and copying it
# to the clipboard. Bound to SUPER+N in hypr/modules/binds.lua. Uses the same
# quick-access-terminal (QAT) mechanism as the fzf pickers (see lib.sh):
# re-sending the same launch command toggles visibility instead of spawning a
# second panel, and the nvim process (and its unsaved buffer) survives a hide.
#
# The clipboard handoff happens in nvim-scratch-quit.sh, run once nvim exits
# (a real :q/:wq, not a hide).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

scratch_group="scratch"
scratch_file="$HOME/.cache/nvim-scratch.md"
run_script="$script_dir/nvim-scratch-run.sh"
quit_script="$script_dir/nvim-scratch-quit.sh"
scratch_qat_config="$HOME/github/dotfiles/kitty/quick-access-terminal-scratch.conf"

# Consumers such as CopyQ need to get the scratch layer out of the way without
# risking a hidden scratch being opened. Detect the mapped layer first, then use
# toggle_qat directly so this hide-only path also avoids launch_qat's keyboard-
# layout switch.
if [[ "${1:-}" == "--hide" ]]; then
  if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 \
    && hyprctl layers -j 2>/dev/null \
      | jq -e '.. | objects | select(.namespace? == "nvim-scratch")' >/dev/null 2>&1; then
    toggle_qat "$scratch_group"
  fi
  exit 0
fi

mkdir -p "$(dirname "$scratch_file")"
touch "$scratch_file"

# The scratch editor intentionally uses a larger dedicated QAT config; picker
# panels keep using the compact shared config from lib.sh.
qat_config="$scratch_qat_config"
launch_qat "$scratch_group" /usr/bin/env bash "$run_script" "$scratch_file" "$quit_script"
