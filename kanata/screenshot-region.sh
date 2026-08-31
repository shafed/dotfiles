#!/usr/bin/env bash

set -o pipefail
. "$(dirname "$0")/screenshot-cursor.sh"

picker_pid=""

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
