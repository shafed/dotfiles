#!/usr/bin/env bash

set -o pipefail

picker_pid=""

cleanup() {
  if [ -n "$picker_pid" ]; then
    kill "$picker_pid" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT HUP INT TERM

# Freeze the screen so transient content doesn't shift while framing the
# selection.
hyprpicker -r -z &
picker_pid=$!
sleep 0.2

geometry=$(slurp -d) || exit 0
[ -n "$geometry" ] || exit 0

# Drop the freeze before the real capture: killing hyprpicker isn't provably
# synchronous, so give its surface a moment to tear down before grim runs,
# otherwise grim just re-photographs the frozen frame instead of the live
# desktop.
kill "$picker_pid" >/dev/null 2>&1 || true
wait "$picker_pid" 2>/dev/null
picker_pid=""
sleep 0.2

grim -g "$geometry" - | wl-copy --type image/png
