#!/usr/bin/env bash
# shellcheck shell=bash

# Shared helpers for the picker scripts in this directory (apps.sh,
# bookmarks.sh, youtube.sh, youtube-qat.sh). Sourced, not executed; everything
# here is safe under `set -euo pipefail`.

fzf_colors_file="$HOME/dotfiles/colorscheme/active/active-fzf-colors.sh"
qat_config="$HOME/dotfiles/kitty/quick-access-terminal-center.conf"
kitty_bin="$(command -v kitty || echo /usr/bin/kitty)"

# Force the keyboard to English so fzf queries type as latin even when the
# active layout is Russian. Index 0 is "us" in hyprland.conf's kb_layout
# (us,ru). Best-effort: silently no-op outside Hyprland.
switch_to_english() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl switchxkblayout all 0 >/dev/null 2>&1 || true
}

# Source the active colorscheme's fzf palette (sets $linkarzu_fzf_colors).
source_fzf_colors() {
  if [[ -f "$fzf_colors_file" ]]; then
    # shellcheck disable=SC1090
    source "$fzf_colors_file"
  fi
}

# Print the remote-control socket of the MAIN kitty process. Each QAT creates
# its own /tmp/kitty-* socket; using the main one keeps hide/show commands from
# accidentally targeting another floating terminal.
main_kitty_socket() {
  local sock pid args

  for sock in /tmp/kitty-*; do
    [[ -S "$sock" ]] || continue
    pid="${sock##*-}"
    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"

    # On Linux the launcher is usually the python entry point; match either the
    # resolved kitty binary or a bare "kitty" command in the process arguments.
    if [[ "$args" == "$kitty_bin"* || "$args" == kitty* || "$args" == *"/kitty "* ]]; then
      printf '%s\n' "$sock"
      return 0
    fi
  done

  return 1
}

# toggle_qat <instance-group> — hide/show the QAT panel of that group. Because
# the panel is single-instance per instance-group, re-sending the same launch
# command flips its visibility instead of spawning a second panel — this is
# what makes re-triggers instant.
toggle_qat() {
  local group="$1" sock

  sock="$(main_kitty_socket)" || return 0
  "$kitty_bin" @ --to "unix:${sock}" \
    action launch --type=background kitten quick-access-terminal \
    --config "$qat_config" \
    --instance-group "$group" >/dev/null 2>&1 || true
}

# launch_qat <instance-group> [command...] — show (or toggle) the QAT panel of
# that group, running [command...] inside it on a cold start.
#
# Forces the English layout first: this runs on EVERY hotkey press, and when
# the panel already exists kitty merely toggles its visibility — the picker
# loop's own switch_to_english never re-runs — so doing it here guarantees the
# layout flips to "us" each time the panel is shown.
launch_qat() {
  local group="$1" sock
  shift

  switch_to_english

  sock="$(main_kitty_socket)" || {
    echo "No main kitty socket found."
    exit 1
  }

  "$kitty_bin" @ --to "unix:${sock}" \
    action launch --type=background kitten quick-access-terminal \
    --config "$qat_config" \
    --instance-group "$group" \
    "$@"
}

###############################################################################
#                    Firefox window helpers (Hyprland + jq)
###############################################################################

# True when any Firefox window exists.
firefox_running() {
  hyprctl clients -j 2>/dev/null | grep -q '"class": *"firefox"'
}

# Print the Hyprland addresses of all current Firefox windows, one per line.
firefox_window_addresses() {
  hyprctl clients -j 2>/dev/null | jq -r '
    .[] | select(.class == "firefox") | .address
  ' 2>/dev/null
}

# Print the address of a Firefox window that is NOT on the given workspace, or
# nothing if every Firefox window is on it (or none exist).
firefox_window_off_workspace() {
  hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$1" '
    .[] | select(.class == "firefox" and .workspace.id != $ws) | .address
  ' 2>/dev/null | head -n1
}

# open_in_new_firefox_window <url> <workspace> — open the URL in a fresh
# Firefox window, then move that window (and only that window) to <workspace>
# and focus it. The window address set is diffed before/after the launch so the
# move targets the newly created window rather than an existing one.
open_in_new_firefox_window() {
  local url="$1" workspace="$2" before after i new_addr=""

  before="$(firefox_window_addresses)"
  # </dev/null: never hand Firefox the caller's tty. A QAT panel stays open
  # while any process holds its tty (kitty close_on_child_death=no), and a
  # Firefox tied to that tty gets killed when the panel is force-closed.
  firefox --new-window "$url" </dev/null >/dev/null 2>&1 &
  disown

  # Wait for a window address that was not present before the launch.
  for i in {1..10}; do
    after="$(firefox_window_addresses)"
    new_addr="$(comm -13 <(printf '%s\n' "$before" | sort) <(printf '%s\n' "$after" | sort) | head -n1)"
    [[ -n "$new_addr" ]] && break
    sleep 0.25
  done

  if [[ -n "$new_addr" ]]; then
    hyprctl dispatch movetoworkspace "${workspace},address:$new_addr" >/dev/null 2>&1 || true
    hyprctl dispatch focuswindow "address:$new_addr" >/dev/null 2>&1 || true
  fi
  return 0
}

# move_firefox_when_up <workspace> — poll for a Firefox window (e.g. right
# after a cold-start xdg-open), then move it to <workspace> and focus it.
#
# The window can take several seconds to appear on a true cold start (process
# launch + profile load + first paint), far longer than the warm case where a
# running Firefox opens a tab almost instantly. So poll generously — ~12s — or
# the cold-start window never gets moved and the tab opens on whatever workspace
# Firefox came up on instead of <workspace>.
move_firefox_when_up() {
  local workspace="$1" i

  for i in {1..48}; do
    if firefox_running; then
      hyprctl dispatch movetoworkspace "${workspace},class:firefox" >/dev/null 2>&1 || true
      hyprctl dispatch focuswindow class:firefox >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.25
  done
  return 0
}
