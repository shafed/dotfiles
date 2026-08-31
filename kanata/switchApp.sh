#!/bin/bash

APP_CLASS="$1"
APP_COMMAND="$2"
KILL_WINDOWLESS="${3:-false}"

if hyprctl clients | grep -q "class: $APP_CLASS"; then
  hyprctl dispatch "hl.dsp.focus({ window = \"class:${APP_CLASS}\" })"
else
  # Window might be momentarily invisible (e.g. during kanata restart when the
  # virtual keyboard device is re-created). Retry a few times before killing.
  for i in 1 2; do
    sleep 0.1
    if hyprctl clients | grep -q "class: $APP_CLASS"; then
      hyprctl dispatch "hl.dsp.focus({ window = \"class:${APP_CLASS}\" })"
      exit 0
    fi
  done
  # Killing a windowless process is opt-in: during a kanata restart Hyprland
  # can temporarily omit a healthy kitty window from `hyprctl clients`.
  if [[ "$KILL_WINDOWLESS" == true ]]; then
    pkill -x "$APP_CLASS" 2>/dev/null
  elif pgrep -x "$APP_CLASS" >/dev/null; then
    exit 0
  fi
  eval "$APP_COMMAND" &
fi
