---
title: yazi
type: component
updated: 2026-07-01
covers:
  - yazi/
---

# yazi

🚧 File manager (TUI). Theme — [[theming]]; launched from [[kitty]]/sessions.

## Plugins (which ones are actually wired in)

Dependencies are pinned in `package.toml` (pinned rev+hash via `ya pack`),
code lives in `plugins/`. Actively used (bindings in `keymap.toml`):

- **relative-motions** — `1`–`9` as relative motions (vim-style jumps through the
  list); configured in `init.lua` (`relative_absolute`, `enter_mode = cache_or_first`).
- **smart-enter** — `l` and `<Enter>`: enters a folder OR opens a file (one key).
- **smart-paste** — `p`: pastes into the hovered folder without entering it.
- **jump-to-char** — `f`: jump to a file by its first letter.
- **lazygit** — `g i`: open lazygit in the current directory.
- **sudo** — prefix `R ...`: paste/rename/link/hardlink/create/remove/chmod as
  root (wrappers over privilege-elevated operations).
- **autosession** — `init.lua` calls `:setup()`; an `<Esc>`-like
  `save-and-quit` in keymap. Saves/restores yazi session state.
- **rich-preview** — preview for markdown/json/csv/ipynb (examples in `plugins/rich-preview.yazi/examples`).

⚠️ Gotcha: `plugins/` has **`clipboard.yazi` (an empty folder — not installed)**
alongside `smart-enter`/`smart-paste`, but do NOT rely on the folder's presence as meaning "enabled" —
the source of truth for what's wired in is `package.toml` + the bindings in `keymap.toml`.
`z`/`Z` (fzf/zoxide) are yazi's built-in plugins, not part of this list.

## yazi.toml

Three columns (`ratio [1,4,3]`), hidden files off by default. Openers:
PDF — viewed via `sioyek` (`LIBGL_ALWAYS_SOFTWARE=1` — works around a GL issue,
commit `ae6cf4b`), annotation — `xournalpp`.

## Theme

`theme.toml`: both `dark` and `light` → `gruvbox-dark` (flavor `bennyyip/gruvbox-dark`
in `flavors/`). ⚠️ Gotcha: yazi does NOT switch to a light theme — both bindings
point to the same dark flavor (deliberate, "always gruvbox dark"). See
[[theming]].
