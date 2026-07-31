#!/bin/bash

APP_CLASS="$1"
APP_COMMAND="$2"

if hyprctl clients | grep -q "class: $APP_CLASS"; then
  hyprctl dispatch "hl.dsp.focus({ window = \"class:${APP_CLASS}\" })"
else
  eval "$APP_COMMAND" &
fi
