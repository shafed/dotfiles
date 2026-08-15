---
title: yazi
type: component
updated: 2026-08-14
covers:
  - yazi/
---

# yazi

File manager (TUI). Theme — [theming](theming.md); launched from
[kitty](kitty.md)/sessions.

## Plugins

Pinned in `package.toml` (rev+hash via `ya pack`), code in `plugins/`, bound in
`keymap.toml`. Those three files are the source of truth for what is actually
wired in — this page does not repeat the list.

⚠️ Gotcha: **a folder under `plugins/` does not mean "installed"** —
`clipboard.yazi` sits there empty. Check `package.toml` and the bindings, not
the directory listing. (`z`/`Z` for fzf/zoxide are yazi built-ins and appear in
neither.)

⚠️ Gotcha: **autosession is gone and cannot be reinstalled** — upstream
`barbanevosa/autosession` 404s, so `ya pkg` can't fetch it. Removed together
with its `q` binding on 2026-07-18 ([decisions](decisions.md)). If you want
session save/restore back, find a different plugin; don't try to resurrect this
one.

## yazi.toml

PDFs open via **plain `sioyek`, with no env prefix on purpose** — the GL
workaround belongs in the `~/.local/bin/sioyek` wrapper, not here. Until
2026-08-09 this line read `LIBGL_ALWAYS_SOFTWARE=1 sioyek`; that variable turned
out to be the bug rather than the fix ([sioyek](sioyek.md)).

⚠️ Gotcha (yazi v26.5.6, 2026-07-18): an upgrade silently reverted the config to
preset defaults. Four breaking renames at once — the `"$schema"` TOML *key* is
rejected ("must be a kebab-cased string") and is now a `#:schema` *comment*;
`title_format` in `[mgr]` is gone (subscribe to the `ind-app-title` DDS event in
`init.lua` instead); `[tasks]`'s `micro_workers`/`macro_workers` became five
separate `*_workers` fields; and `[plugin]` fetcher rules renamed `id` → `group`
and made it **required**, so a missing `group` hard-fails parsing rather than
warning. If a yazi upgrade ever throws a parse error again, diff
`yazi-config/preset/yazi-default.toml` from the `sxyazi/yazi` repo against this
`yazi.toml` — fastest way to spot renamed fields.

## Theme

⚠️ Gotcha: both the `dark` and `light` slots in `theme.toml` point at the same
gruvbox-dark flavor. This is deliberate — yazi never goes light, so darkman's
switch does not reach it ([theming](theming.md)).
