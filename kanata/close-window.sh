#!/bin/bash
# apps+q: graceful close, except telegram (which just minimizes to tray on a
# graceful close) gets force-killed so it actually quits.
class="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')"

if [ "$class" = "org.telegram.desktop" ]; then
  hyprctl dispatch "hl.dsp.window.kill()"
else
  hyprctl dispatch "hl.dsp.window.close()"
fi
