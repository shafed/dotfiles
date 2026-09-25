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

# Capture the frozen frame before closing hyprpicker. Hover-only surfaces,
# such as Helium's tab sidebar, disappear when the pointer leaves them while
# selecting the region.
grim -g "$geometry" - | wl-copy --type image/png
