---
title: quickshell-pickers
type: component
updated: 2026-08-30
covers:
  - quickshell/DesktopLauncher.qml
  - quickshell/BookmarksPicker.qml
  - quickshell/launcher-usage.py
  - quickshell/palette-helper.py
  - quickshell/prepare-launcher.py
  - quickshell/prepare-ui-fixes.py
  - quickshell/dots-shell
  - kanata/config.kbd
---

# Quickshell pickers

Parent: [quickshell](quickshell.md). The old terminal pickers are documented in
[scripts-pickers](scripts-pickers.md); they remain useful as standalone/fallback
scripts, but the active kanata routes for applications and bookmarks now open
Quickshell.

## Why Applications and Bookmarks are separate

A combined command palette was tried and reverted. It made application-specific
behavior (desktop-entry icons, running-window detection and focus/open) depend on
generic provider delegates, which regressed icons and produced false `RUNNING`
state. Separate pickers keep each data contract small while preserving the same
visual language and keyboard navigation.

`apps+a` opens Applications. `apps+b` opens Bookmarks. Both are keyboard-first;
mouse selection is deliberately absent. `Esc` closes, arrows or `Ctrl-J/K` move
selection, and `Enter` acts on the selected row.

## Applications

Applications uses Quickshell's `DesktopEntries.applications` directly rather
than parsing `.desktop` files in a subprocess. The original launcher
implementation was retained because its desktop-entry icon resolution and
focus/open behavior are tied to Quickshell's native application model.

The empty query is usage-oriented. Counts are shared with the former fzf app
picker through `~/.cache/apps-fzf/usage.tsv`, so moving between the two UIs does
not throw away history. A selection through Quickshell increments the same
counter.

Typing does not disable usage weighting. The launcher's own fuzzy score remains
the relevance gate, then `prepare-ui-fixes.py` adds a bounded logarithmic usage
bonus to that score. Repeated use can promote a plausible match such as Helium
for `browser`, but usage cannot make an unrelated application pass the fuzzy
filter.

⚠️ Gotcha: the usage bonus is currently applied to the generated runtime copy of
`DesktopLauncher.qml`; when debugging ranking, inspect
`~/.cache/dots-shell/quickshell/DesktopLauncher.qml`, not only the tracked file.

Enter focuses an already-running matching toplevel when one is found; Alt+Enter
always asks the desktop entry to start a new instance. The `RUNNING` marker uses
the same matching path, so a matching regression affects both marker and Enter
behavior.

## Bookmarks: Quickshell UI, fzf ranking

Bookmarks deliberately keeps **fzf as the matcher**. Quickshell owns the window,
input and row rendering; `palette-helper.py` passes the complete
`name<TAB>url` catalog to `fzf --filter`. This preserves the fuzzy behavior that
made the old QAT picker useful instead of reimplementing a weaker matcher in
QML.

Frequency is added **after**, not instead of, fzf. fzf first decides which rows
match and their relevance order. The helper then applies a small logarithmic
bonus from `~/.cache/bookmarks-fzf/usage.tsv` to the returned rank. The default
weight is `0.65` (`DOTFILES_BOOKMARK_FREQUENCY_WEIGHT` can override it). A
frequently opened bookmark can move a few nearby positions, but it cannot enter
the result set unless fzf matched it.

The empty query remains recency-first and reads
`~/.cache/bookmarks-fzf/recent.tsv`. Selecting a bookmark updates both recency
and frequency before calling the existing `open_or_focus_url` browser helper,
so BruvTab tab reuse and workspace placement stay shared with the old script.

## Favicons

Bookmark icons come from Helium's local Chromium `Favicons` SQLite database,
not from a web favicon service. The helper copies the database (including WAL
files when present) to a temporary snapshot before reading it, so an open
browser does not race the picker. Extracted PNGs are cached under
`~/.cache/bookmarks-fzf/favicons/` by URL hash.

The browser `Bookmarks` JSON is also exported to the same cache namespace when
the picker opens. Generated browser data therefore never dirties the dotfiles
worktree. If the Favicons database has no usable row, the UI falls back to the
bookmark's first letter rather than making a network request.

## Runtime integration

`prepare.py` builds the native shell, then `center-title.py` and
`agents-panel.py` apply the current top-bar/AI presentation. Only after those
stages does `prepare-launcher.py` insert/copy the two picker components;
`prepare-ui-fixes.py` then adds application usage weighting and the standard
system-popover dismiss behavior. The picker integration deliberately does not
own or replace the top bar.

`dots-shell launcher` targets the Applications IPC handler; `dots-shell
bookmarks` targets the separate Bookmarks handler. System panels are a different
path and close picker overlays before opening.
