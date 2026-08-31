#!/usr/bin/env bash
# Shared hardware/software cursor toggle for the screenshot-*.sh wrappers.
# See wiki/kanata.md#Screenshots for why this exists and what to watch for.

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
