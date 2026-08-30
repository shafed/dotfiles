---
title: quickshell-pickers
type: component
updated: 2026-08-30
covers:
  - quickshell/components/DesktopLauncher.qml
  - quickshell/components/BookmarksPicker.qml
  - quickshell/launcher-usage.py
  - quickshell/palette-helper.py
  - quickshell/dots-shell
  - kanata/config.kbd
---

# Quickshell pickers

Parent: [quickshell](quickshell.md). The old terminal pickers remain documented
in [scripts-pickers](scripts-pickers.md) as standalone/fallback tools; active
kanata routes for applications and bookmarks open Quickshell.

Applications and Bookmarks intentionally remain separate components. Combining
them made desktop-entry icons and running-window detection depend on generic
provider delegates, which regressed those application-specific behaviors. Both
components share the visual constants from `config/UiConfig.qml` and the
generated Gruvbox palette from `config/Colors.qml`.

`apps+a` opens Applications; `apps+b` opens Bookmarks. Both are keyboard-first:
`Esc` closes, arrows or `Ctrl-J/K` move selection, and `Enter` acts on the row.

## Applications

Applications uses `DesktopEntries.applications` directly. The empty query is
usage-oriented; counts are shared with the old fzf picker through
`~/.cache/apps-fzf/usage.tsv`.

Typing keeps usage weighting. The launcher's fuzzy score remains the relevance
gate, then a bounded logarithmic usage bonus is added among plausible matches.
This logic now lives directly in `components/DesktopLauncher.qml`; there is no
generated-runtime ranking patch. Enter focuses an existing matching toplevel
when possible; Alt+Enter always executes a new instance. `RUNNING` uses the same
matching path.

## Bookmarks

Bookmarks deliberately keeps **fzf as the matcher**. Quickshell owns the window,
input and row rendering; `palette-helper.py` gives the complete `name<TAB>url`
catalog to `fzf --filter`. Frequency is applied after fzf relevance, with the
same `~/.cache/bookmarks-fzf/usage.tsv` and recency cache as the fallback picker.

Favicons come from Helium's local Chromium `Favicons` SQLite database via a
temporary snapshot; extracted PNGs are cached under
`~/.cache/bookmarks-fzf/favicons/`. Missing favicons fall back to the first
letter and never trigger a network request.

## Runtime integration

`components/DesktopLauncher.qml` and `components/BookmarksPicker.qml` are copied
with the rest of the modular QML tree by `prepare.py`. `dots-shell launcher` and
`dots-shell bookmarks` keep their existing IPC targets. System panels,
clipboard and pickers close other shell overlays before opening, preserving the
single-overlay contract.
