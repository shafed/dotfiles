---
title: quickshell
type: component
updated: 2026-08-30
covers:
  - quickshell/shell.qml
  - quickshell/prepare.py
  - quickshell/start.sh
  - quickshell/layout-watch.py
  - quickshell/backend.py
  - systemd/user/quickshell.service
  - systemd/user/layout-osd.service
---

# Quickshell

Quickshell is the active Hyprland bar and desktop shell. It replaced Waybar so
bar state, popups, OSD, notifications and related desktop UI can live in one
process instead of being split across independent tools.

## Runtime QML

`shell.qml` is intentionally kept as the base source while `prepare.py` applies
the current Hyprland-specific bar changes into a generated config under
`~/.cache/dots-shell/quickshell` before startup. This keeps the migration
patches small and makes source drift fail loudly instead of silently producing a
partially broken bar.

⚠️ Gotcha: the running QML is the generated copy, not `shell.qml` directly.
Changing only `shell.qml` can have no effect if `prepare.py` transforms the same
block; changing an expected source block can also make `prepare.py` abort at
startup.

## Event-driven state

Workspace state uses Quickshell's native Hyprland objects rather than the old
800 ms backend polling path. This was chosen because polling made workspace
highlights visibly late and routed mouse switching through an unnecessary Python
round trip.

Keyboard layout is pushed directly to the shell instead of using the generic
refresh path. A layout change should update only the layout state; triggering a
full refresh here reintroduces unnecessary work and can let stale snapshots
overwrite a fresh event.

## Clock and power

The clock opens the calendar because it is a general desktop action. Power
controls stay attached to the battery entry on laptops instead of overloading
the clock with an unrelated panel.

## Maintenance

After changing Quickshell code:

```sh
systemctl --user restart quickshell.service layout-osd.service
```

If startup fails, check:

```sh
journalctl --user -u quickshell.service -n 100 --no-pager
journalctl --user -u layout-osd.service -n 100 --no-pager
```
