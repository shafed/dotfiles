---
title: quickshell
type: component
updated: 2026-08-30
covers:
  - quickshell/shell.qml
  - quickshell/prepare.py
  - quickshell/center-title.py
  - quickshell/agents-panel.py
  - quickshell/agents-refresh.py
  - quickshell/prepare-launcher.py
  - quickshell/prepare-ui-fixes.py
  - quickshell/start.sh
  - quickshell/backend.py
  - quickshell/dots-shell
  - systemd/user/quickshell.service
---

# Quickshell

Quickshell is the active Hyprland bar and desktop shell. Realtime desktop state
belongs in the long-running QML process; separate watcher daemons are avoided so
an input event does not have to cross Python, IPC and another scheduler before
it becomes visible.

Applications and bookmarks are also desktop-facing Quickshell pickers. Their
ranking/data contracts are intentionally separate from the bar; see
[quickshell-pickers](quickshell-pickers.md).

## Runtime QML

`shell.qml` is still the base source and `prepare.py` builds the generated config
under `~/.cache/dots-shell/quickshell`. `prepare.py` is a build-time migration
shim, not a realtime backend. The eventual cleanup target is to fold stable
transformations back into QML and remove shims rather than grow another runtime
layer.

`start.sh` applies post-processors in order: `center-title.py`,
`agents-panel.py`, `prepare-launcher.py`, then `prepare-ui-fixes.py`.
`center-title.py` and `agents-panel.py` own the top-bar title/AI presentation;
the picker stages do not replace those blocks. `prepare-launcher.py` only
inserts the standalone picker components and overlay IPC, while
`prepare-ui-fixes.py` owns popover dismissal plus application usage weighting.

⚠️ Gotcha: the running QML is the generated copy, not `shell.qml` directly.
Changing a source block that a post-processor expects can make startup fail with
the missing block name. When debugging generated behavior inspect
`~/.cache/dots-shell/quickshell/`, not only tracked QML.

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
updates, network/Bluetooth discovery, notification persistence, clipboard
operations and bookmark catalog/fzf integration.

## Desktop popovers

System panels use one fullscreen layer-shell surface with the visible card
anchored at the top-right. The rest of the surface is the dismiss area. This
replaces the two-surface "panel + transparent dismiss window" approach, whose
focus/pointer ordering was unreliable under layer-shell.

The contract is the normal popover one: `Esc` closes; the first click outside
closes and is consumed; clicks inside remain inside the panel; opening another
shell overlay closes the previous one.

The active-window title remains geometrically centered by `center-title.py`, so
unequal left/right status blocks cannot move it away from the physical center of
the monitor.

## AI limits

The AI panel intentionally shows account rate limits only: **Current session**
and **Weekly limits**, with utilization bars and reset times. Local token totals,
sessions and per-model history are not part of this UI.

`agents-refresh.py` runs once when Quickshell starts, again when the AI panel is
opened, and on the Refresh button. That direct path bypasses the five-minute
`agents` snapshot cache and updates the panel. Once a direct refresh has produced
rows, later slow snapshots preserve them instead of replacing them with the
legacy cached AI state.

For Claude, the weekly value follows the web Usage page's **All models** bucket:
`seven_day` is preferred over `seven_day_oauth_apps`. The OAuth-app bucket is
only a fallback because it can differ substantially from what the website
labels as Weekly limits. If a live request fails, the last cached limits remain
visible and are marked `cached` rather than silently pretending to be fresh.

The top-bar `AI` label stays neutral. Warning color belongs to each utilization
percentage/bar inside the panel: under 70% used is green, 70–89% amber, and 90%+
red. This keeps the warning attached to the limit that caused it.

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
