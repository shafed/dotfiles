---
title: waybar
type: component
updated: 2026-08-03
covers:
  - waybar/config.jsonc
  - waybar/style.css
---

# waybar

🚧 Status bar for Hyprland. Colors — [theming](theming.md).

## Layout and modules

Bar at the top, height 30. Layout:

- **left**: `hyprland/workspaces` (icons, `all-outputs`), `hyprland/submap`,
  `custom/media`.
- **center**: `hyprland/window` (active window title).
- **right**: `pulseaudio`, `network`,
  `hyprland/language` (layout indicator), `battery`, `clock`,
  `tray`, `custom/power`.

  `mpd`, `power-profiles-daemon` and `battery#bat2` were removed (2026-08-03):
  the `mpd` and `power-profiles-daemon` packages are not installed on this
  machine, and there's no `BAT2` battery (only `BAT1`, auto-detected by the
  plain `battery` module).

⚠️ Gotcha: some modules are commented out in `modules-right` (`idle_inhibitor`,
`cpu`, `memory`, `temperature`, `keyboard-state`, `backlight`) — their configs
remain in the file, but they aren't shown on the bar. Don't be surprised by
"dead" config blocks.

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

- **`custom/media`** — `exec: $HOME/.config/waybar/mediaplayer.py` (JSON,
  playerctl/MPRIS). ⚠️ The `mediaplayer.py` script does NOT live in this repo (expected at
  `~/.config/waybar/`); dotfiles only has `config.jsonc` and `style.css`.
- **`custom/power`** — a `⏻` button with a click menu (`menu-file:
  power_menu.xml`, also outside the repo): shutdown/reboot/suspend/hibernate.
- **`hyprland/language`** — shows the layout that kanata switches
  (see [keymap](keymap.md)); waybar only displays the state.
- **`backlight`** — laptop-only: needs `/sys/class/backlight/<device>`, which the
  desktop (DP-2 monitor) doesn't expose, so it's commented out here. Re-enable
  on a laptop.

## style.css — gruvbox

Colors are set via `@define-color gb_*` (the full gruvbox palette: bg `#282828`,
fg `#d4be98`, accents red/green/yellow/orange/blue/purple/aqua). The bar is semi-transparent
(`rgba(40,40,40,0.88)`). This is a local copy of the palette (not a shared source) — the same
approach as in kitty/nvim; the single color guide is [theming](theming.md).
