---
title: quickshell
type: component
updated: 2026-08-30
covers:
  - quickshell/shell.qml
  - quickshell/prepare.py
  - quickshell/realtime.py
  - quickshell/start.sh
  - quickshell/layout-watch.py
  - quickshell/brightness-watch.py
  - quickshell/backend.py
  - systemd/user/quickshell.service
  - systemd/user/layout-osd.service
  - systemd/user/brightness-osd.service
---

# Quickshell

Quickshell is the active Hyprland bar and desktop shell. It replaced Waybar so
bar state, popups, OSD, notifications and related desktop UI can live in one
shell instead of being split across independent bars and helpers.

## Runtime QML

`shell.qml` is the base source. `prepare.py` builds the generated config under
`~/.cache/dots-shell/quickshell`; `realtime.py` then adds bindings that depend on
live desktop services before Quickshell starts. Source drift is intentionally a
hard error rather than silently producing a partially transformed bar.

⚠️ Gotcha: the running QML is the generated copy, not `shell.qml` directly.
When changing a block that a runtime transform expects, update the transform as
well or startup will fail with the missing block name.

## Realtime state

Anything where visible latency matters must not depend on the old periodic
backend snapshot. Workspaces use Quickshell's native Hyprland model, keyboard
layout comes from Hyprland Socket2 events, and volume/mute use Quickshell's
native PipeWire binding. Brightness has no equivalent shell binding here, so a
small watcher reads the kernel backlight value directly and only publishes when
it changes.

This is why the old 800 ms fast polling loop is deliberately disabled. Slow
state such as package updates, battery metadata and agent usage can remain on
coarser snapshots without making direct user actions feel delayed.

## Clock and power

The clock opens the calendar because it is a general desktop action. Power
controls stay attached to the battery entry on laptops instead of overloading
the clock with an unrelated panel.

## Maintenance

After changing Quickshell code:

```sh
systemctl --user daemon-reload
systemctl --user restart quickshell.service
```

If startup fails, check:

```sh
journalctl --user -u quickshell.service -n 100 --no-pager
journalctl --user -u layout-osd.service -n 100 --no-pager
journalctl --user -u brightness-osd.service -n 100 --no-pager
```
