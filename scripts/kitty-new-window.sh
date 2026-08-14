#!/usr/bin/env bash

# Filename: ~/dotfiles/scripts/kitty-new-window.sh
# Bound to Super+Return in hypr/hyprland.lua in place of a bare `exec kitty`.
#
# A bare `exec kitty` starts a brand-new, independent kitty process every
# press: it has no source window to inherit a session from, so its first tab
# gets session_name "" forever, and kitty-list-sessions.sh's main_kitty_socket
# only ever queries one process anyway, so a second one is invisible to the
# picker regardless. Worse, kitty_mod+t's `--add-to-session .` blindly
# inherits whatever session the current window has, so tabs opened inside
# that orphan process stay orphaned too. See wiki/sessions.md.
#
# Routing through the main kitty's remote-control socket instead opens a new
# OS window inside the one tracked process, tagged into a session like
# everything else.

set -euo pipefail

dotfiles_dir="$HOME/dotfiles"
# shellcheck source=./lib.sh
source "$dotfiles_dir/scripts/lib.sh"

# Cold start: no main kitty running yet, nothing to attach to.
sock="$(main_kitty_socket)" || exec "$kitty_bin"

exec "$kitty_bin" @ --to "unix:${sock}" action launch --type=os-window --add-to-session .
