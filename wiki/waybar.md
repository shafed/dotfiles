---
title: waybar
type: component
updated: 2026-08-14
covers:
  - waybar/config.jsonc
  - waybar/style.css
---

# waybar

Status bar for Hyprland. Colors — [theming](theming.md).

⚠️ Gotcha: several modules keep full config blocks while being absent from
`modules-right` (`idle_inhibitor`, `cpu`, `memory`, `temperature`,
`keyboard-state`, `backlight`) — a configured module is not a displayed one.

## waybar-git vs release (Hyprland 0.55+ Lua)

The **AUR `waybar-git`** package is required: Hyprland 0.55+ evaluates
`hyprctl dispatch` args as Lua, and only waybar master auto-detects that and
sends `hl.dsp.*` dispatches from the workspace buttons. The stock 0.15.0
release sends legacy `dispatch workspace N`, which fails silently — clicking a
workspace in the bar does nothing. See [hypr](hypr.md).

With waybar-git, two modules were dropped/renamed vs 0.15.0:
`hyprland/mode` is now `hyprland/submap` (config key), and
`hyprland/scratchpad` was removed entirely (its function is covered by the
workspaces module's `show-special` option). The config was updated accordingly.

## Custom modules (scripts/menus)

- ⚠️ **Two custom modules depend on files this repo does not contain**:
  `custom/media` needs `~/.config/waybar/mediaplayer.py` and `custom/power`
  needs `power_menu.xml`. Only `config.jsonc` and `style.css` are versioned
  here, so a fresh machine gets a bar with two broken modules and no clue why.
- **`hyprland/language`** only *displays* the layout — kanata is what switches
  it ([keymap](keymap.md)). Don't try to change layout behavior from here.
- **`backlight`** is commented out because it needs `/sys/class/backlight/<dev>`,
  which this desktop doesn't expose. Re-enable on a laptop.

## style.css — gruvbox

The `@define-color gb_*` palette here is a **local copy**, not a shared source —
same as kitty/nvim. Changing a shade means editing every component;
[theming](theming.md) lists them all.
