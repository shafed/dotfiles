---
title: quickshell-pickers
type: component
updated: 2026-08-30
covers:
  - quickshell/components/DesktopLauncher.qml
  - quickshell/components/BookmarksPicker.qml
  - quickshell/components/QuickPicker.qml
  - quickshell/components/YoutubePicker.qml
  - quickshell/components/ClipboardOverlay.qml
  - quickshell/picker-helper.py
  - quickshell/youtube-helper.py
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

All picker surfaces are keyboard-first. `Esc` closes or backs out of a nested
view, arrows or `Ctrl-J/K` move selection, and `Enter` acts on the selected row.
Projects/zoxide and open Kitty Sessions are intentionally keyboard-only: row
hover/click and pointer scrolling are disabled, so a pointer over the centered
surface cannot steal navigation. Sessions additionally accepts `Ctrl-D`/Delete
to close the selected session and `Ctrl-R` to refresh.

Opening a picker closes the other Quickshell overlays so there is only one
exclusive keyboard-focus surface at a time.

## Applications

Applications intentionally remains its own component rather than going through
the generic provider picker. It uses `DesktopEntries.applications` directly so
desktop-entry icons, running-window detection and `Alt+Enter` new-instance
behavior stay native to the application model.

The empty query is usage-oriented; counts are shared with the old fzf picker
through `~/.cache/apps-fzf/usage.tsv`. `DesktopLauncher.qml` owns that TSV with
`FileView` instead of invoking a Python read/write helper. Writes remain atomic
and keep the historical `<desktop-id>.desktop<TAB><count>` format, so switching
to the fallback picker remains lossless.

Typing keeps usage weighting: the launcher's fuzzy score remains the relevance
gate, then a bounded logarithmic usage bonus is added among plausible matches.
Enter focuses an existing matching toplevel when possible; Alt+Enter always
executes a new instance. `RUNNING` uses the same matching path.

Matching runs entirely in QML (no helper process), so highlighting is computed
locally too: `DesktopLauncher.qml` re-derives the fuzzy character positions
against the displayed name/subtitle text and renders only those characters in
the Gruvbox accent/bold style, same visual language as Bookmarks/Projects/
Sessions/YouTube. A match found only through the id, keywords or the
first-letter acronym (not a substring of the visible text) highlights nothing
— there is no position in the shown text to point at.

## Bookmarks

Bookmarks also remains separate because it has browser-specific data and icon
handling. Quickshell owns the window, input and row rendering;
`palette-helper.py` gives the complete `name<TAB>url` catalog to
`fzf --filter`. Frequency is applied after fzf relevance, with the same
`~/.cache/bookmarks-fzf/usage.tsv` and recency cache as the fallback picker.

Favicons come from Helium's local Chromium `Favicons` SQLite database via a
temporary snapshot; extracted PNGs are cached under
`~/.cache/bookmarks-fzf/favicons/`. Missing favicons fall back to the first
letter and never trigger a network request. This SQLite/binary extraction is
intentionally still a bounded Python helper rather than QML shell state.

`palette-helper.py` also returns the character positions its own greedy scan
found in `name`/`url` (`nameMatches`/`urlMatches`) — the same best-effort
scheme as `youtube-helper.py`/`picker-helper.py`, not a literal readout of
fzf's internal match. Since fzf scores the whole `name<TAB>url` line as one
string, a row can match (and rank) via characters that only line up once the
two fields are joined, in which case neither field highlights anything on its
own — a known, accepted gap. `BookmarksPicker.qml` renders both in the
Gruvbox accent/bold style.

## Projects and Sessions

`components/QuickPicker.qml` is the shared renderer for Projects and Sessions.
It asks `picker-helper.py` for JSON rows and keeps filtering, selection and
keyboard handling inside Quickshell. Those two views deliberately do not expose
mouse row navigation or pointer scrolling.

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

Typing also applies the same frequency-weighted ranking as Bookmarks/YouTube:
`picker-helper.py` persists open counts in `~/.cache/quickpicker/usage.tsv`,
keyed `<provider>:<row id>` (`projects`/`sessions` share the file but not the
namespace, so a project and a session can't collide on the same key) and
bumped from `open`. The bonus (`0.65 * log2(count + 1)`, scaled up to be
comparable to the fuzzy scorer's own ~10-unit position deltas) only applies
once a query is typed — the empty-query order is untouched. It also returns
`titleMatches`/`subtitleMatches`, the character positions its greedy fuzzy
scan found, which `QuickPicker.qml` renders in the Gruvbox accent/bold style
like the other pickers.

## YouTube

YouTube has its own `components/YoutubePicker.qml` because the old QAT picker has
richer state than a generic text provider: search source, channel drill-down,
video/stream tabs, deep channel history and a visual preview. QML owns the view
state while `youtube-helper.py` adapts the existing `scripts/youtube.sh`
subcommands, so yt-dlp, browser cookies, caches and workspace-4 placement are not
reimplemented in QML.

The native picker supports the interactive behavior that previously required the
QAT/fzf surface:

- `Ctrl-V` → video search;
- `Ctrl-C` → channel search;
- `Ctrl-H` → signed-in watch history;
- `Ctrl-L` → signed-in Watch later;
- `Enter` on a channel → drill into that channel without opening the browser;
- `Ctrl-S` inside a channel → toggle uploads / streams;
- `Ctrl-A` inside a channel → load the deep videos cache (up to 2000 rows);
- `Esc` inside a channel → return to the previous search/source;
- `Enter` on a video/page → open through the existing browser-placement logic on
  workspace 4.

YouTube ranking follows the same principle as Applications and Bookmarks: the
provider/fuzzy order stays primary, then frequency may move a result only a few
nearby positions. Counts are persisted in `~/.cache/youtube-fzf/usage.tsv`; the
default bonus is `0.65 * log2(count + 1)` and can be overridden with
`DOTFILES_YOUTUBE_FREQUENCY_WEIGHT`. Opening a video or drilling into a channel
records usage.

`youtube-helper.py` also returns character positions matched by the fuzzy query
for title and subtitle. `YoutubePicker.qml` renders only those characters in the
generated Gruvbox accent/bold style, preserving the useful match visibility of
fzf/QAT without putting markup into underlying IDs or titles.

The right side previews the selected video's YouTube thumbnail, title, duration
and channel when available. Thumbnail loading is asynchronous and uses Qt's
image cache. Mouse selection remains available for this visual picker, but is
armed only after actual pointer movement so a stationary cursor under the new
layer surface does not override the initial keyboard selection.

History and Watch later reuse `youtube.sh --ythistory` / `--ytwatchlater`. Their
short-lived Quickshell cache keeps filtering local while the existing background
channel enrichment fills in channel names. Channel videos/streams reuse
`--yttab` and its per-tab cache; deep mode uses a distinct cache so the normal
40-row cache cannot satisfy a 2000-row request accidentally.

The standalone `youtube.sh` remains useful for direct CLI channel/playlist calls,
manual refreshes and custom `-n` limits, but normal `apps+u` no longer needs its
fzf/QAT frontend for search, history, Watch later or channel browsing.

## Clipboard

`Super+V` opens `components/ClipboardOverlay.qml`. The input receives active
focus as soon as the layer-shell surface opens, so the clipboard is fully usable
without a mouse. Selection starts on the first row even when the pointer is
already over the centered panel; hover navigation is armed only after at least
4 px of actual pointer movement.

- type to filter visible history rows;
- arrows or `Ctrl-J/K` move selection;
- `Enter` pastes the selected item;
- `Esc` closes.

Paste is deliberately dispatched about 160 ms after the overlay is hidden. The
clipboard window has exclusive layer-shell keyboard focus; sending `Ctrl+V`
immediately can race surface teardown and feed the synthetic paste back into the
closing overlay instead of the previously focused app. `cliphist` remains the
preferred source and CopyQ remains the fallback.

## Scratch note

`Super+N` is also native Quickshell now; see [scripts-scratch](scripts-scratch.md).
It is a separate editor overlay because its state is a draft, not a selectable
provider list.

## Runtime integration

Tracked QML is run directly; there is no `prepare.py` runtime-copy step.
`dots-shell` centralizes overlay routing and exposes `launcher`, `bookmarks`,
`projects`, `sessions`, `youtube`, `clipboard` and `scratch`. YouTube has its own
IPC target; Projects and Sessions continue through `quickpicker`. The wrapper
closes competing IPC targets before opening the requested surface, preserving
the single-overlay contract.

⚠️ Gotcha (`dots-shell`'s IPC target must self-locate, not default to the old
runtime-copy path): `quickshell ipc -p <path>` matches the literal _resolved_
`shell.qml` path of a running instance, not just wherever `<path>` eventually
leads — so it does not transparently follow `~/.config/quickshell` if that
symlink is itself the `-p` argument passed straight through. `start.sh` runs
`quickshell -p "$root"` where `$root` is `dots-shell`'s own directory
(`readlink -f` of its own `${BASH_SOURCE[0]}`, so it works the same whether
invoked directly or through the `~/.config/quickshell` symlink). Before this,
`dots-shell` defaulted to `${XDG_CACHE_HOME:-~/.cache}/dots-shell/quickshell`
— correct back when `start.sh` still ran `prepare.py` into that path, but
stale once "quickshell: run tracked qml tree directly" removed that copy step
without updating `dots-shell`'s default to match. Symptom: every hotkey
(`apps+a/b/e/c/u`, clipboard, scratch, panels — all of them, not just one)
silently failed with `No running instances for ".../shell.qml"` even though
`quickshell.service` was up and reloading cleanly. `QUICKSHELL_CONFIG_DIR`
still overrides both when set, e.g. to point at an isolated worktree.

⚠️ Gotcha (`~/.config/quickshell` is a movable symlink, not a fixed target):
it's meant to point at whichever checkout is "active" — normally this repo,
but it can be repointed at an isolated worktree for live-testing a picker
change in isolation. If a prior session leaves it pointed at a stale worktree
and never restores it, every hotkey routes to that worktree's (possibly much
older) QML and `dots-shell` instead of this repo's — `./dots apply
--links-only` re-links it back to `$ROOT/quickshell` (refuses to touch it only
if something replaced it with a real, non-symlink directory).
