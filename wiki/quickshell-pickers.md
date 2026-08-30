---
title: quickshell-pickers
type: component
updated: 2026-08-30
covers:
  - quickshell/components/DesktopLauncher.qml
  - quickshell/components/BookmarksPicker.qml
  - quickshell/components/QuickPicker.qml
  - quickshell/components/ClipboardOverlay.qml
  - quickshell/picker-helper.py
  - quickshell/launcher-usage.py
  - quickshell/palette-helper.py
  - quickshell/dots-shell
  - kanata/config.kbd
---

# Quickshell pickers

Parent: [quickshell](quickshell.md). Quickshell is now the active UI for all
keyboard-facing pickers that used to be launched as kitty QAT panels. The old
terminal/fzf scripts remain in [scripts-pickers](scripts-pickers.md) as manual
fallback tools, but the normal hotkey routes no longer depend on a QAT window.

The active apps-layer routes are:

- `apps+a` → Applications;
- `apps+b` → Bookmarks;
- `apps+e` → Projects (named kitty sessions, zoxide dirs, SSH hosts);
- `apps+c` → open Kitty Sessions;
- `apps+u` → YouTube.

All picker surfaces are keyboard-first. `Esc` closes, arrows or `Ctrl-J/K` move
selection, and `Enter` acts on the selected row. The Sessions view additionally
accepts `Ctrl-D`/Delete to close the selected session and `Ctrl-R` to refresh.
Opening a picker closes the other Quickshell overlays so there is only one
exclusive keyboard-focus surface at a time.

## Applications

Applications intentionally remains its own component rather than going through
the generic provider picker. It uses `DesktopEntries.applications` directly so
desktop-entry icons, running-window detection and `Alt+Enter` new-instance
behavior stay native to the application model.

The empty query is usage-oriented; counts are shared with the old fzf picker
through `~/.cache/apps-fzf/usage.tsv`. Typing keeps usage weighting: the
launcher's fuzzy score remains the relevance gate, then a bounded logarithmic
usage bonus is added among plausible matches. Enter focuses an existing matching
toplevel when possible; Alt+Enter always executes a new instance. `RUNNING` uses
the same matching path.

## Bookmarks

Bookmarks also remains separate because it has browser-specific data and icon
handling. Quickshell owns the window, input and row rendering;
`palette-helper.py` gives the complete `name<TAB>url` catalog to
`fzf --filter`. Frequency is applied after fzf relevance, with the same
`~/.cache/bookmarks-fzf/usage.tsv` and recency cache as the fallback picker.

Favicons come from Helium's local Chromium `Favicons` SQLite database via a
temporary snapshot; extracted PNGs are cached under
`~/.cache/bookmarks-fzf/favicons/`. Missing favicons fall back to the first
letter and never trigger a network request.

## Projects, Sessions and YouTube

`components/QuickPicker.qml` is the shared renderer for the remaining generic
pickers. It does not duplicate the old fzf UI; it asks `picker-helper.py` for
JSON rows and keeps search, selection and keyboard handling inside Quickshell.

Projects combines the same three sources the old zoxide QAT exposed:

- tracked `kitty/sessions/*.kitty-session` named sessions;
- `zoxide query -l` directories;
- concrete SSH hosts from `~/.ssh/config`, including `Include` files.

Selecting a directory reuses an existing Kitty session whose cwd matches when
possible; otherwise the helper writes the same kind of transient session under
`~/.cache/kitty-sessions/`. Named and SSH entries also route through Kitty's
remote-control `goto_session`, and a main Kitty window is started only when a
session action actually needs one.

Sessions reads `kitty @ ls`, deduplicates by `session_name`, sorts by recent
focus and marks the active session `CURRENT`. Opening uses the named/transient
session file when available. Closing a row uses Kitty's `close_session` action.

YouTube reuses `scripts/youtube.sh --ytsearch` as the data source rather than
reimplementing YouTube extraction. Video and channel searches run in parallel;
Enter opens a video or channel using the existing browser-placement helpers, so
YouTube still lands on workspace 4. With an empty query the panel exposes Watch
Later, History and Subscriptions shortcuts. The old `youtube.sh` interface is
still available manually for its deeper channel/history/watch-later fzf modes.

## Clipboard

`Super+V` opens `components/ClipboardOverlay.qml`. The input receives active
focus as soon as the layer-shell surface opens, so the clipboard is fully usable
without a mouse. Selection starts on the first row and a stationary pointer does
not steal it; hover selection is armed only after the pointer actually moves.

- type to filter visible history rows;
- arrows or `Ctrl-J/K` move selection;
- `Enter` pastes the selected item;
- `Esc` closes.

Paste is deliberately dispatched about 160 ms after the overlay is hidden. The
clipboard window has exclusive layer-shell keyboard focus; sending `Ctrl+V`
immediately can race surface teardown and feed the synthetic paste back into the
closing overlay instead of the previously focused app.

## Scratch note

`Super+N` is also native Quickshell now; see [scripts-scratch](scripts-scratch.md).
It is a separate editor overlay because its state is a draft, not a selectable
provider list.

## Runtime integration

`prepare.py` copies the modular QML tree into the runtime cache. `dots-shell`
centralizes overlay routing and exposes `launcher`, `bookmarks`, `projects`,
`sessions`, `youtube`, `clipboard` and `scratch`. The wrapper closes competing
IPC targets before opening the requested surface, preserving the single-overlay
contract.
