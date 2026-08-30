---
title: quickshell
type: component
updated: 2026-08-30
covers:
  - quickshell/shell.qml
  - quickshell/prepare.py
  - quickshell/start.sh
  - quickshell/backend.py
  - systemd/user/quickshell.service
---

# Quickshell

Quickshell is the active Hyprland bar and desktop shell. Realtime desktop state
belongs in the long-running QML process; separate watcher daemons are avoided so
an input event does not have to cross Python, IPC and another scheduler before
it becomes visible.

## Runtime QML

`shell.qml` is still the base source and `prepare.py` builds the generated config
under `~/.cache/dots-shell/quickshell`. `prepare.py` is a build-time migration
shim, not a realtime backend. The eventual cleanup target is to fold stable
transformations back into QML and remove the shim rather than grow another
runtime layer.

⚠️ Gotcha: the running QML is the generated copy, not `shell.qml` directly.
Changing a source block that `prepare.py` expects can make startup fail with the
missing block name.

## Realtime state

Latency-sensitive state stays inside Quickshell:

- workspaces use `Quickshell.Hyprland` objects directly;
- keyboard layout follows `Hyprland.rawEvent` / `activelayout`;
- volume and mute use `Quickshell.Services.Pipewire` with `PwObjectTracker`;
- brightness is sampled from the kernel backlight file inside QML because
  Quickshell 0.3.1 has no brightness service and sysfs does not provide a
  reliable change event on every driver.

There is no 800 ms fast snapshot and no audio/layout/brightness watcher service.
Python remains for slow or integration-heavy data such as AI usage, package
updates, network/Bluetooth discovery, notification persistence and clipboard
operations.

## Clock and power

The clock opens the calendar. Power controls remain attached to the battery
entry on laptops.

## Maintenance

After changing Quickshell code:

```sh
systemctl --user daemon-reload
systemctl --user reset-failed
systemctl --user restart quickshell.service
```

If startup fails:

```sh
journalctl --user -u quickshell.service -n 100 --no-pager -o cat
```
