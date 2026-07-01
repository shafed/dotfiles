---
title: waybar
type: component
updated: 2026-07-01
covers:
  - waybar/config.jsonc
  - waybar/style.css
---

# waybar

🚧 Status bar for Hyprland. Colors — [theming](theming.md).

## Layout and modules

Bar at the top, height 30. Layout:

- **left**: `hyprland/workspaces` (icons, `all-outputs`), `hyprland/mode`,
  `hyprland/scratchpad`, `custom/media`.
- **center**: `hyprland/window` (active window title).
- **right**: `mpd`, `pulseaudio`, `network`, `power-profiles-daemon`, `backlight`,
  `hyprland/language` (layout indicator), `battery` + `battery#bat2`, `clock`,
  `tray`, `custom/power`.

⚠️ Gotcha: some modules are commented out in `modules-right` (`idle_inhibitor`,
`cpu`, `memory`, `temperature`, `keyboard-state`) — their configs remain in the file,
but they aren't shown on the bar. Don't be surprised by "dead" config blocks.

## Custom modules (scripts/menus)

- **`custom/media`** — `exec: $HOME/.config/waybar/mediaplayer.py` (JSON,
  playerctl/MPRIS). ⚠️ The `mediaplayer.py` script does NOT live in this repo (expected at
  `~/.config/waybar/`); dotfiles only has `config.jsonc` and `style.css`.
- **`custom/power`** — a `⏻` button with a click menu (`menu-file:
  power_menu.xml`, also outside the repo): shutdown/reboot/suspend/hibernate.
- **`hyprland/language`** — shows the layout that kanata switches
  (see [keymap](keymap.md)); waybar only displays the state.

## style.css — gruvbox

Colors are set via `@define-color gb_*` (the full gruvbox palette: bg `#282828`,
fg `#d4be98`, accents red/green/yellow/orange/blue/purple/aqua). The bar is semi-transparent
(`rgba(40,40,40,0.88)`). This is a local copy of the palette (not a shared source) — the same
approach as in kitty/nvim; the single color guide is [theming](theming.md).
