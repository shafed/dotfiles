#!/usr/bin/env bash

# switchApp.sh <wm-class> <command> — focus an already-open window of the app
# (matched by Hyprland WM class) or launch <command> when none exists.

set -euo pipefail

app_class="${1:?usage: switchApp.sh <wm-class> <command>}"
app_command="${2:?usage: switchApp.sh <wm-class> <command>}"

if hyprctl clients | grep -q "class: $app_class"; then
  hyprctl dispatch focuswindow "class:$app_class"
else
  eval "$app_command" &
fi
