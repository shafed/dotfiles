#!/usr/bin/env bash

set -o pipefail

picker_pid=""
cursor_mode=$(hyprctl getoption cursor:no_hardware_cursors -j 2>/dev/null | jq -r '.int // 1')
cursor_mode=${cursor_mode:-1}
cursor_mode_changed=0

# Hyprland's Lua config parser rejects `hyprctl keyword` at runtime
# ("Use eval."); config-table options must go through `hyprctl eval`.
set_cursor_mode() {
  local bool="false"
  [ "$1" -eq 1 ] && bool="true"
  hyprctl eval "hl.config({cursor={no_hardware_cursors=$bool}})" >/dev/null 2>&1
}

restore_cursor_mode() {
  if [ "$cursor_mode_changed" -eq 1 ]; then
    set_cursor_mode "$cursor_mode"
    cursor_mode_changed=0
  fi
}

use_hardware_cursor() {
  set_cursor_mode 0
  cursor_mode_changed=1
  # The mode switch is asynchronous; grim/hyprpicker must not run until it
  # has actually taken effect or they still capture the software cursor.
  sleep 0.5
}

cleanup() {
  restore_cursor_mode
  if [ -n "$picker_pid" ]; then
    kill "$picker_pid" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT HUP INT TERM

# Freeze the screen so transient content doesn't shift while framing the
# selection. hyprpicker's freeze snapshot bakes in whatever cursor is visible
# when it's taken, so take it in hardware-cursor mode too: killing hyprpicker
# before the real capture (below) isn't provably synchronous, and if its
# surface is still being torn down when grim runs, a cursor-free frozen frame
# is what grim ends up re-photographing anyway.
use_hardware_cursor
hyprpicker -r -z &
picker_pid=$!
sleep 0.2
restore_cursor_mode

geometry=$(slurp -d) || exit 0
[ -n "$geometry" ] || exit 0

# Drop the freeze before the real capture: grim would otherwise re-photograph
# hyprpicker's already-frozen frame instead of the live desktop.
kill "$picker_pid" >/dev/null 2>&1 || true
wait "$picker_pid" 2>/dev/null
picker_pid=""
sleep 0.2

# Software cursors are part of the composited frame and get copied by grim.
# Briefly use the hardware cursor plane, which screencopy excludes.
use_hardware_cursor
grim -g "$geometry" - | wl-copy --type image/png
