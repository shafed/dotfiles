#!/usr/bin/env bash

set -o pipefail
. "$(dirname "$0")/screenshot-cursor.sh"

trap restore_cursor_mode EXIT HUP INT TERM

output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
[ -n "$output" ] || exit 1

use_hardware_cursor
grim -o "$output" - | wl-copy --type image/png
