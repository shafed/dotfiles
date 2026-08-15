#!/bin/bash

APP_CLASS="$1"
APP_COMMAND="$2"

if hyprctl clients | grep -q "class: $APP_CLASS"; then
  hyprctl dispatch "hl.dsp.focus({ window = \"class:${APP_CLASS}\" })"
else
  # no window but a same-named process may already be running and stuck
  # (e.g. sioyek looping on an EGL context failure); a stuck process
  # blocks new launches via single-instance IPC, so clear it first
  pkill -x "$APP_CLASS" 2>/dev/null
  eval "$APP_COMMAND" &
fi
