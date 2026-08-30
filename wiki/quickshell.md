---
title: quickshell
type: component
updated: 2026-08-30
covers:
  - quickshell/shell.qml
  - quickshell/components/
  - quickshell/services/
  - quickshell/config/
  - quickshell/prepare.py
  - quickshell/agents-refresh.py
  - quickshell/picker-helper.py
  - quickshell/start.sh
  - quickshell/backend.py
  - quickshell/dots-shell
  - systemd/user/quickshell.service
---

# Quickshell

Quickshell is the active Hyprland bar and desktop shell. Realtime desktop state
belongs in the long-running QML process; separate watcher daemons are avoided so
an input event does not cross Python/IPC before it becomes visible.

All active desktop-facing pickers now belong to Quickshell: Applications,
Bookmarks, Projects, open Kitty Sessions, YouTube and Clipboard. `Super+N` also
uses a native Quickshell scratch editor instead of a terminal QAT. Data and
ranking contracts remain separate from the bar; see
[quickshell-pickers](quickshell-pickers.md).

## Runtime QML

Tracked QML is the runtime source instead of a base file plus ordered string
post-processors:

- `shell.qml` — orchestration, slow backend state, notifications, process lifetimes
  and IPC;
- `components/` — top bar, system panel, compact system overview, searchable
  hotkeys cheat sheet, clipboard/toast/OSD overlays, shared controls,
  Applications, Bookmarks, the shared Projects/Sessions/YouTube picker and the
  scratch editor;
- `services/DesktopServices.qml` — realtime PipeWire volume/mute, Hyprland
  keyboard layout events and sysfs backlight sampling;
- `config/UiConfig.qml` — declarative fonts, geometry, sizing and timers;
- `config/Colors.qml` — generated from repository-level `colors.toml`.

`prepare.py` only copies this modular tree to
`$XDG_CACHE_HOME/dots-shell/quickshell`; `start.sh` then runs that copy. The old
`center-title.py`, `agents-panel.py`, `prepare-agents-refresh-ui.py`,
`prepare-launcher.py` and `prepare-ui-fixes.py` build-time rewrites were folded
into tracked QML and removed. Debugging the cache is still useful, but there is
no second QML logic representation to keep in sync.

## Realtime state

Latency-sensitive state stays inside Quickshell:

- workspaces use `Quickshell.Hyprland` objects directly;
- keyboard layout follows `Hyprland.rawEvent` / `activelayout`, ignoring
  `hl-virtual-keyboard`;
- volume and mute use `Quickshell.Services.Pipewire` with `PwObjectTracker`;
- brightness is sampled from the kernel backlight file inside
  `DesktopServices` because Quickshell 0.3.1 has no brightness service and
  sysfs does not provide a reliable change event on every driver.

There is no 800 ms fast snapshot and no audio/layout/brightness watcher service.
Python remains for slow/integration-heavy data such as AI usage, package
updates, network/Bluetooth discovery, notification persistence and clipboard
history. Picker-specific integrations that need external programs live in
`picker-helper.py`: zoxide/SSH/Kitty session state and YouTube extraction. The
full backend snapshot runs every 15 s and after actions.

Kanata's apps-layer volume, mute and brightness chords do not add another
control backend: Kanata emits the standard XF86 media/backlight key events,
Hyprland owns the corresponding `wpctl`/`brightnessctl` commands, and the native
Quickshell services observe the resulting state.

## Desktop popovers and pickers

System panels use one fullscreen layer-shell surface with the visible card
anchored at the top-right. The rest is the dismiss area: `Esc` closes; the first
outside click closes and is consumed; clicks inside remain inside the card;
opening another shell overlay closes the previous one. This behavior is in
`components/SystemPanel.qml`.

`dots-shell system` toggles the compact `components/SystemOverview.qml` in that
same surface. It exposes Audio, Network/Wi-Fi, Bluetooth, Power, AI limits,
Updates, Notifications and Calendar. The overview is only navigation and state
presentation: selecting an entry switches to the existing detailed panel rather
than duplicating its controls or backend. Network and Bluetooth remain reachable
from the overview even when their top-bar buttons are hidden on a non-laptop.
Its height is declared in `config/UiConfig.qml`.

Repeated `dots-shell system` closes the overview because it uses the existing
`dots panel system` toggle. Applications, Bookmarks, Projects, Sessions,
YouTube, Clipboard, Scratch and Hotkeys are mutually exclusive with system
panels and with one another. `dots-shell` closes the competing IPC targets before
opening the requested surface.

`components/QuickPicker.qml` is the shared UI for Projects, Sessions and
YouTube. Its `TextInput` gets focus on show; arrows/`Ctrl-J/K` navigate, Enter
opens and Esc closes. Sessions also support `Ctrl-D`/Delete. Provider rows and
actions are supplied as JSON by `picker-helper.py`; see
[quickshell-pickers](quickshell-pickers.md).

`components/ClipboardOverlay.qml` uses the same keyboard contract and adds
inline filtering. Clipboard paste is scheduled shortly after hiding the
exclusive layer-shell surface so the synthetic `Ctrl+V` reaches the previously
focused application rather than racing the overlay teardown.

`components/ScratchOverlay.qml` is a focused multiline editor. `Esc` hides while
preserving the draft and `Ctrl+Enter` closes, copies and pastes back into the
window that was focused before scratch opened. Details and the retained legacy
nvim/QAT fallback are in [scripts-scratch](scripts-scratch.md).

`Super+F1` runs `dots-shell hotkeys`, which toggles
`components/HotkeysPanel.qml`. It is a centered fullscreen overlay using the
same generated Gruvbox colors and declarative UI sizing as the rest of the
shell. `Esc`, the first outside click, or another `Super+F1` closes it.

The Hotkeys component keeps only a small static searchable presentation index of
the main Hyprland, Kanata and active custom Kitty shortcuts. It does not parse
configs or start a process when opening, so toggle latency stays local to the
running QML process. The real keymap source of truth remains
`hypr/hyprland.lua`, `kanata/config.kbd` and `kitty/kitty.conf`; see
[keymap](keymap.md).

The active-window title remains geometrically centered against the physical bar
width, now in `components/TopBar.qml`.

## AI limits

The AI panel shows account rate limits only: **Current session** and **Weekly
limits**, with utilization bars and reset times. `agents-refresh.py` runs at
startup, when the panel is opened and from the compact `↻` control. The header
shows `Last updated: just now` and then minute/hour/day-relative age; the
refresh control is disabled and dimmed while a refresh is running. The
timestamp advances only after parsable rows return. Once a direct refresh has
produced rows, slow snapshots do not replace them with the legacy cached rows.

For Claude, Weekly follows the web Usage page's **All models** bucket:
`seven_day` is preferred over `seven_day_oauth_apps`; the OAuth-app bucket is a
fallback. Failed live refreshes leave cached limits visible and marked `cached`.

The top-bar `AI` label reflects the most constrained current account limit: it
stays neutral while more than 30% remains, turns amber at 30% remaining or less,
and red at 10% remaining or less. Per-limit percentages/bars inside the panel
keep their own green/amber/red utilization colors as well.

## Maintenance

After changing Quickshell code:

```sh
python3 scripts/generate-theme.py --check
systemctl --user daemon-reload
systemctl --user reset-failed
systemctl --user restart quickshell.service
```

If startup fails:

```sh
journalctl --user -u quickshell.service -n 100 --no-pager -o cat
```
