#!/usr/bin/env bash
# Toggle a floating kitty+nvim scratchpad for jotting a note and pasting it
# into whatever window had focus before the scratchpad opened. Bound to
# SUPER+N in hypr/hyprland.conf. Uses the same quick-access-terminal (QAT)
# mechanism as the fzf pickers (see lib.sh): re-sending the same launch
# command toggles visibility instead of spawning a second panel, and the
# nvim process (and its unsaved buffer) survives a hide.
#
# The actual copy+paste happens in nvim-scratch-quit.sh, run once nvim exits
# (a real :q/:wq, not a hide).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

scratch_group="scratch"
scratch_file="$HOME/.cache/nvim-scratch.md"
state_file="$HOME/.cache/nvim-scratch-target"
run_script="$script_dir/nvim-scratch-run.sh"
quit_script="$script_dir/nvim-scratch-quit.sh"

mkdir -p "$(dirname "$scratch_file")"
touch "$scratch_file"

# Harmless if the panel is about to hide instead of show (state_file is only
# read once nvim actually exits, which can't happen while hidden); correct
# when it's about to show, which is the case that matters.
hyprctl activewindow -j | jq -r '.address // empty' >"$state_file"

launch_qat "$scratch_group" /usr/bin/env bash "$run_script" "$scratch_file" "$quit_script"
