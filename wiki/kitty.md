---
title: kitty
type: component
updated: 2026-07-17
covers:
  - kitty/
---

# kitty

🚧 Terminal and multiplexer (native sessions instead of tmux). Sessions in detail —
[sessions](sessions.md); colors — [theming](theming.md).

## ⚠️ Gotcha: kitty.conf is ~3000 lines, but the customization is a handful of lines

`kitty/kitty.conf` is a dump from `kitten themes` with ALL the defaults in comments.
Do NOT read it in full. The actual (uncommented) settings can be gotten like this:

```sh
grep -vE '^\s*#' kitty/kitty.conf | grep -vE '^\s*$'
```

Everything substantive boils down to:

- **Font/cursor**: JetBrains Mono 14, `cursor_blink_interval 0`, `cursor_trail 1`
  (cursor trail).
- **Scroll/mouse**: `wheel_scroll_multiplier 3.0`, `copy_on_select yes`,
  `mouse_hide_wait -1` (cursor doesn't hide).
- **Appearance**: `hide_window_decorations yes`, `tab_bar_style powerline`,
  `include current-theme.conf` (gruvbox, see below), borders matching the theme.
- **Remote control**: `allow_remote_control yes` + `listen_on unix:/tmp/kitty-{kitty_pid}`
  — enabled FOR the session pickers and QAT panels (they talk via `kitten @`).
- **Sessions**: `startup_session .../home.kitty-session` (kitty starts WITHOUT tmux,
  commit `65d18e9`), `tab_bar_filter session:~ ...`, the tab title template
  shows the session name. Everything about sessions is in [sessions](sessions.md).
- **`kitty_mod+i`** — open scrollback in the nvim pager (yank from the panel's history).
  Runs `scripts/kitty-scrollback-nvim.sh`, which trims trailing blank lines from
  both sources of padding: kitty's `@screen_scrollback` (full screen grid) via sed,
  and `nvim_open_term()`'s buffer padding via deferred lua.

## `pass_keys.py` — contextual Ctrl-h/j/k/l navigation

`map ctrl+h/j/k/l → kitten pass_keys.py`. ⚠️ Key idea: **the same keys
serve both as kitty window navigation and as input inside a child program**. The kitten looks
at the window's foreground process: if it's `nvim` OR `fzf` (the default regex
`n?vim|fzf`), the key is passed through (nvim splits, moving through an fzf list);
otherwise `boss.active_tab.neighboring_window(direction)` moves focus between kitty
windows. The regex is overridable via the 4th argument of the binding. This replaces
Hyprland window navigation inside the terminal (commit `24b289d`).

## `get_layout.py` — the name of the current layout

A tiny custom kitten (`handle_result` returns `active_tab.current_layout.name`,
`no_ui`). Used by scripts/sessions to find out the current kitty panel
layout from under `kitten @`. Not to be confused with the keyboard layout (that's kanata's job).

## `toggle_tab_bar.py` — hide/show the tab bar at runtime

Custom `no_ui` kitten (`hide`/`show`/`toggle` args) that pokes
`tab.tab_manager_ref().tab_bar_hidden` directly and calls `tm.resize()`. Needed
because kitty's remote-control protocol has no builtin command for this —
`tab_bar_hidden` is normally set exactly once at startup, from
`tab_bar_style == "hidden"` (`kitty/tabs.py`). Driven from nvim
(`nvim/lua/utils/fullscreen.lua`) so `Snacks.zen` (`<leader>uz`) hides the tab
bar and fullscreens the Hyprland window on open, restoring both on close.

## QAT panels (quick-access-terminal)

Drop-down overlay panels for fzf pickers ([scripts](scripts.md): bookmarks/youtube):

- `quick-access-terminal-center.conf` — centered (`edge center-sized`,
  22×90, `background_opacity 0.85`), with a full duplication of the gruvbox palette via
  `kitty_override` and `tab_bar_style=hidden`.
- `quick-access-terminal-right.conf` — anchored to the right edge, no transparency,
  tab bar hidden. ⚠️ Gotcha: `<M-t>` inside toggles the geometry/hides the tab bar
  of the floating panel (commits `4c315a0`/`b0cad6e`).

## current-theme.conf

Gruvbox Material Dark Medium (`background #282828` matching nvim — commit `e5557fc`).
Details and why this particular color source was chosen — [theming](theming.md).
