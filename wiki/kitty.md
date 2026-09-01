---
title: kitty
type: component
updated: 2026-09-01
covers:
  - kitty/
---

# kitty

Terminal and multiplexer (native sessions instead of tmux). Sessions in detail —
[sessions](sessions.md); colors — [theming](theming.md).

## ⚠️ Gotcha: kitty.conf is ~3000 lines, but the customization is a handful of lines

`kitty/kitty.conf` is a dump from `kitten themes` with ALL the defaults in comments.
Do NOT read it in full. The actual (uncommented) settings can be gotten like this:

```sh
grep -vE '^\s*#' kitty/kitty.conf | grep -vE '^\s*$'
```

The settings that carry a reason worth knowing:

- ⚠️ **Font**: the `Mono` variant of JetBrains Mono Nerd Font is deliberate — the
  plain `ttf-jetbrains-mono` package was removed from the system, so naming the
  unpatched family would silently fall back to PT Mono and lose ligatures. The
  `Mono` variant is also narrower, which has bitten nvim float sizing
  ([nvim-ui](nvim-ui.md)).
- **Remote control** (`allow_remote_control` + `listen_on
  unix:/tmp/kitty-{kitty_pid}`) exists **for** the session pickers and QAT
  panels, which drive kitty via `kitten @`. Turning it off breaks
  [scripts-pickers](scripts-pickers.md) and [sessions](sessions.md), not just convenience.
- **Terminal notifications are filtered globally** (`filter_notification all`):
  CLI agents such as Codex and Claude Code use kitty's notification protocol,
  and their completion prompts were unwanted. This does not disable desktop
  notifications from applications outside kitty.
- **`kitty_mod+i`** opens scrollback in an nvim pager via
  `scripts/kitty-scrollback-nvim.sh`. ⚠️ It trims trailing blank lines from
  **two** independent sources of padding — kitty's `@screen_scrollback` returns
  the full screen grid (trimmed with sed) and `nvim_open_term()` pads the buffer
  again (trimmed with deferred lua). Fixing only one leaves the blank tail.

## `pass_keys.py` — contextual Ctrl-h/j/k/l navigation

⚠️ Key idea: **the same keys serve both as kitty window navigation and as input
inside a child program**. The kitten dispatches on the window's foreground
process — `nvim`/`fzf` get the key passed through, anything else moves focus
between kitty windows. This is what replaces Hyprland window navigation inside
the terminal, so changing it affects both layers.

## `toggle_tab_bar.py` — hide/show the tab bar at runtime

A custom kitten exists here only because **kitty's remote-control protocol has
no builtin command to toggle the tab bar** — `tab_bar_hidden` is normally set
exactly once at startup from `tab_bar_style == "hidden"` (`kitty/tabs.py`), so
the kitten pokes it directly and calls `tm.resize()`. Driven from nvim's zen
mode (`nvim/lua/utils/fullscreen.lua`, see [nvim-ui](nvim-ui.md)).

⚠️ The action arg is `args[1]`, not `args[0]` — kitty puts the script path
first. Before this was fixed (2026-08-03) `hide`/`show` were dead branches and
the kitten always toggled.

## QAT panels (quick-access-terminal)

Drop-down overlay panels hosting the fzf pickers in [scripts-pickers](scripts-pickers.md) and
the session pickers in `kitty/scripts/` ([sessions](sessions.md)). Their config
(`quick-access-terminal-center.conf`) carries **another full copy of the gruvbox
palette** via `kitty_override` — one of the duplication sites
[theming](theming.md) warns about.
