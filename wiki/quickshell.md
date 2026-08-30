---
title: quickshell
type: component
updated: 2026-08-30
covers:
  - quickshell/shell.qml
  - quickshell/components/
  - quickshell/services/
  - quickshell/config/
  - quickshell/picker-helper.py
  - quickshell/youtube-helper.py
  - quickshell/palette-helper.py
  - quickshell/start.sh
  - quickshell/dots-shell
  - systemd/user/quickshell.service
---

# Quickshell

Quickshell is the active Hyprland bar and desktop shell. Desktop state belongs
in the long-running QML process; a general Python snapshot/backend is deliberately
avoided so UI state and actions do not cross a Python/JSON IPC boundary.

All active desktop-facing pickers belong to Quickshell: Applications,
Bookmarks, Projects, open Kitty Sessions, YouTube and Clipboard. `Super+N` also
uses a native Quickshell scratch editor instead of a terminal QAT. Data and
ranking contracts remain separate from the bar; see
[quickshell-pickers](quickshell-pickers.md).

## Runtime QML

Tracked QML is the runtime source and `start.sh` runs that tree directly with
`quickshell -p`. There is no generated runtime copy and no `prepare.py`.

- `shell.qml` — orchestration, notifications, process lifetimes and IPC;
- `components/` — top bar, system panel, compact system overview, searchable
  hotkeys cheat sheet, clipboard/toast/OSD overlays, shared controls,
  Applications, Bookmarks, the shared Projects/Sessions picker, the dedicated
  YouTube picker and the scratch editor;
- `services/DesktopServices.qml` — PipeWire outputs/streams/volume/mute,
  Hyprland keyboard layout events and sysfs backlight sampling;
- `services/SystemServices.qml` — composition of native UPower/Bluetooth plus
  the slower QML services;
- `services/NetworkService.qml` — NetworkManager state/actions through `nmcli`
  processes owned by Quickshell;
- `services/UpdatesService.qml` — package update checks/actions through
  Quickshell processes;
- `services/NotificationStore.qml` — DND and notification history persisted by
  `FileView`/`JsonAdapter`;
- `services/AgentsService.qml` — Claude usage HTTP plus Codex app-server
  JSON-RPC, cache fallback and refresh lifecycle;
- `config/UiConfig.qml` — declarative fonts, geometry, sizing and timers;
- `config/Colors.qml` — generated from repository-level `colors.toml`.

The former `backend.py` general snapshot/action layer, `prepare.py`,
`agents-refresh.py` and `launcher-usage.py` were removed. Python is no longer in
the normal bar/system-panel/Applications runtime path.

## Desktop state

Latency-sensitive state stays inside Quickshell:

- workspaces use `Quickshell.Hyprland` objects directly;
- keyboard layout follows `Hyprland.rawEvent` / `activelayout`, ignoring
  `hl-virtual-keyboard`;
- audio devices and application streams use `Quickshell.Services.Pipewire` with
  `PwObjectTracker`; changing the default output and stream volume no longer
  shells out to `wpctl`;
- Bluetooth uses `Quickshell.Bluetooth` directly;
- battery and power profiles use `Quickshell.Services.UPower` directly;
- brightness is sampled from the kernel backlight file inside
  `DesktopServices` because Quickshell 0.3.1 has no brightness service and
  sysfs does not provide a reliable change event on every driver;
- uptime is read from `/proc/uptime` with `FileView`;
- notification history/DND is stored atomically by `JsonAdapter` rather than a
  Python state writer;
- clipboard history is read/pasted with Quickshell `Process`/`execDetached`;
- Applications usage counts are read and atomically written by `FileView` while
  retaining the historical `~/.cache/apps-fzf/usage.tsv` format.

Network intentionally does **not** use `Quickshell.Networking` yet. Quickshell
0.3.x has had reconnect/disconnect and NetworkManager-restart reliability issues;
`NetworkService.qml` keeps the proven `nmcli` behavior while moving polling,
parsing and actions out of Python and into the shell process. This is a narrow
compatibility boundary, not a second state daemon.

Package update checks similarly run as bounded Quickshell processes every ten
minutes. There is no 15-second Python full snapshot anymore.

Kanata's apps-layer volume, mute and brightness chords do not add another
control backend: Kanata emits the standard XF86 media/backlight key events,
Hyprland owns the corresponding `wpctl`/`brightnessctl` commands, and the native
Quickshell services observe the resulting state.

## Remaining helpers

Python remains only for picker integrations where it still buys meaningful
integration value rather than acting as shell plumbing:

- `picker-helper.py` handles zoxide/SSH/Kitty provider integrations;
- `youtube-helper.py` adapts the existing yt-dlp/cookie/cache YouTube commands,
  usage weighting and fuzzy-match metadata for the native YouTube picker;
- `palette-helper.py` keeps the browser-specific bookmark catalog/fzf path and
  Chromium `Favicons` SQLite snapshot/extraction.

The Chromium favicon helper stays outside QML deliberately: SQLite snapshot/WAL
handling and binary PNG extraction are clearer and safer as a bounded helper
than as shell state. These helpers run only for explicit picker work; none is a
permanent watcher or general desktop-state snapshot.

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
than duplicating its controls. Network and Bluetooth remain reachable from the
overview even when their top-bar buttons are hidden on a non-laptop. Its height
is declared in `config/UiConfig.qml`.

Repeated `dots-shell system` closes the overview because it uses the existing
`dots panel system` toggle. Applications, Bookmarks, Projects, Sessions,
YouTube, Clipboard, Scratch and Hotkeys are mutually exclusive with system
panels and with one another. `dots-shell` closes the competing IPC targets before
opening the requested surface.

`components/QuickPicker.qml` is the shared UI for Projects and Sessions. Its
`TextInput` gets focus on show; arrows/`Ctrl-J/K` navigate, Enter opens and Esc
closes. Sessions also support `Ctrl-D`/Delete. Both lists are intentionally
keyboard-only: row click/hover and pointer scrolling are disabled. Provider rows
and actions are supplied as JSON by `picker-helper.py`; see
[quickshell-pickers](quickshell-pickers.md).

`components/YoutubePicker.qml` owns YouTube's richer UI: videos/channels,
signed-in History and Watch Later, channel drill-down, videos/streams, deep
channel loading and a right-side thumbnail preview. Search ranking keeps
provider/fuzzy relevance primary and adds a bounded logarithmic usage bonus;
matched query characters are rendered with the generated Gruvbox accent. The
picker has its own `youtube` IPC target.

`components/ClipboardOverlay.qml` uses the same keyboard contract and adds
inline filtering. Clipboard paste is scheduled shortly after hiding the
exclusive layer-shell surface so the synthetic `Ctrl+V` reaches the previously
focused application rather than racing the overlay teardown. `cliphist` is the
preferred source; CopyQ remains a fallback. A pointer already under the centered
surface does not steal the initial first-row selection; mouse hover is armed only
after at least 4 px of actual movement.

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
width, now in `components/TopBar.qml`. The workspace strip keeps the focused
positive-ID workspace visible even when it has no windows; inactive empty
workspaces remain hidden.

## AI limits

The AI panel shows account rate limits only: **Current session** and **Weekly
limits**, with utilization bars and reset times. `services/AgentsService.qml`
refreshes at shell startup, when the panel is opened, from the compact `↻`
control and from the shell refresh IPC. The header shows `Last updated: just
now` and then minute/hour/day-relative age; the refresh control is disabled and
dimmed while a refresh is running.

Claude credentials are read from `CLAUDE_CONFIG_DIR` or `~/.claude`; the OAuth
usage endpoint is requested directly from QML. Weekly follows the web Usage
page's **All models** bucket: `seven_day` is preferred over
`seven_day_oauth_apps`, with the OAuth-app bucket only as a fallback.

Codex runs `codex ... app-server` as a Quickshell `Process` with stdin enabled.
The service performs `initialize`, `account/read` and
`account/rateLimits/read` as line-delimited JSON-RPC and bounds every phase with
a timeout. There is no intermediary Python subprocess.

Rows are cached at `~/.cache/dots-shell/agents.json`. Failed live refreshes keep
previous limits visible and mark them `cached`; a successful refresh atomically
replaces the cache. The top-bar `AI` label reflects the most constrained current
account limit: it stays neutral while more than 30% remains, turns amber at 30%
remaining or less, and red at 10% remaining or less. Per-limit bars retain their
own green/amber/red utilization colors.

## Maintenance

`config/Colors.qml` and `config/UiConfig.qml` both declare QML `color`
properties, so they must import `QtQuick`; importing only `QtQml` makes shell
loading fail with `color is not a type` before any component is created.
Components that declare `IpcHandler`, `Process` or `FileView` must import
`Quickshell.Io`; the generic `import Quickshell` does not expose those types.

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
