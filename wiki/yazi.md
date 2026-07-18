---
title: yazi
type: component
updated: 2026-07-18
covers:
  - yazi/
---

# yazi

🚧 File manager (TUI). Theme — [theming](theming.md); launched from [kitty](kitty.md)/sessions.

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
- **rich-preview** — preview for markdown/json/csv/ipynb (examples in `plugins/rich-preview.yazi/examples`).

⚠️ Gotcha: **autosession** (`barbanevosa/autosession`, session save/restore on `q`)
was removed 2026-07-18 — its upstream GitHub repo (`barbanevosa/autosession`) is
gone (404), so it can't be reinstalled via `ya pkg`. `package.toml`, `plugins/`,
`init.lua`, and the `q` binding in `keymap.toml` were all cleaned up together; if
you want session save/restore back, look for a replacement plugin rather than
reinstalling this one.

⚠️ Gotcha: `plugins/` has **`clipboard.yazi` (an empty folder — not installed)**
alongside `smart-enter`/`smart-paste`, but do NOT rely on the folder's presence as meaning "enabled" —
the source of truth for what's wired in is `package.toml` + the bindings in `keymap.toml`.
`z`/`Z` (fzf/zoxide) are yazi's built-in plugins, not part of this list.

## yazi.toml

Three columns (`ratio [1,4,3]`), hidden files off by default. Openers:
PDF — viewed via `sioyek` (`LIBGL_ALWAYS_SOFTWARE=1` — works around a GL issue,
commit `ae6cf4b`), annotation — `xournalpp`.

⚠️ Gotcha (2026-07-18, yazi v26.5.6): the `"$schema" = "..."` TOML-key convention
in `yazi.toml`/`keymap.toml` is dead — new yazi rejects it at startup ("must be
a kebab-cased string") and falls back to preset defaults. Upstream now uses a
`#:schema ...` *comment* instead. Same version also dropped `title_format` in
`[mgr]` (replaced by subscribing to the `ind-app-title` DDS event in `init.lua`
— see the `ps.sub_remote` call there for the `"Yazi: {cwd}"` equivalent),
renamed `[tasks]`'s `micro_workers`/`macro_workers` to five separate
`*_workers` fields (file/plugin/fetch/preload/process), and renamed the `id`
key on `[plugin]` fetcher rules to `group` (and made it required — a fetcher
entry missing `group` hard-fails config parsing, not just warns). If yazi ever
throws a parse error like this again after an upgrade, diff
`yazi-config/preset/yazi-default.toml` from the `sxyazi/yazi` repo against this
`yazi.toml` first — it's the fastest way to spot renamed/removed fields.

## Theme

`theme.toml`: both `dark` and `light` → `gruvbox-dark` (flavor `bennyyip/gruvbox-dark`
in `flavors/`). ⚠️ Gotcha: yazi does NOT switch to a light theme — both bindings
point to the same dark flavor (deliberate, "always gruvbox dark"). See
[theming](theming.md).
