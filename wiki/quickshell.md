---
title: quickshell
type: component
updated: 2026-08-30
covers:
  - quickshell/shell.qml
  - quickshell/prepare.py
  - quickshell/event-state.py
  - quickshell/start.sh
  - quickshell/layout-watch.py
  - quickshell/audio-watch.py
  - quickshell/brightness-watch.py
  - quickshell/backend.py
  - systemd/user/quickshell.service
  - systemd/user/layout-osd.service
  - systemd/user/audio-osd.service
  - systemd/user/brightness-osd.service
---

# Quickshell

Quickshell is the active Hyprland bar and desktop shell. It replaced Waybar so
bar state, popups, OSD, notifications and related desktop UI can live in one
shell instead of being split across independent bars and helpers.

## Runtime QML

`shell.qml` is the base source. `prepare.py` builds the generated config under
`~/.cache/dots-shell/quickshell`; `event-state.py` removes the obsolete fast
polling path and adds the small IPC hooks used by event watchers. Source drift
is intentionally a hard error rather than silently producing a partially
transformed bar.

⚠️ Gotcha: the running QML is the generated copy, not `shell.qml` directly.
When changing a block that a runtime transform expects, update the transform as
well or startup will fail with the missing block name.

## Realtime state

Anything where visible latency matters must not depend on the periodic backend
snapshot. Workspaces use Quickshell's native Hyprland model. Keyboard layout
comes from Hyprland Socket2. Audio changes are observed from PipeWire/Pulse
events and pushed through IPC. Brightness is read directly from the kernel
backlight interface and published only when it changes.

The watcher services are tied to the graphical session, not to
`quickshell.service`. A shell crash therefore cannot repeatedly stop/start the
watchers and push them into `start-limit-hit`.

Slow state such as package updates, battery metadata and agent usage can remain
on coarse snapshots without making direct user actions feel delayed.

## Clock and power

The clock opens the calendar because it is a general desktop action. Power
controls stay attached to the battery entry on laptops instead of overloading
the clock with an unrelated panel.

## Maintenance

After changing Quickshell code:

```sh
systemctl --user daemon-reload
systemctl --user reset-failed quickshell.service layout-osd.service audio-osd.service brightness-osd.service
systemctl --user restart layout-osd.service audio-osd.service brightness-osd.service quickshell.service
```

If startup fails, check:

```sh
journalctl --user -u quickshell.service -n 100 --no-pager
journalctl --user -u layout-osd.service -n 100 --no-pager
journalctl --user -u audio-osd.service -n 100 --no-pager
journalctl --user -u brightness-osd.service -n 100 --no-pager
```
