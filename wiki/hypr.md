---
title: hypr
type: component
updated: 2026-07-01
covers:
  - hypr/hyprland.conf
  - hypr/hypridle.conf
  - hypr/hyprlock.conf
  - hypr/hyprsunset.conf
---

# hypr

🚧 The compositor (Wayland). The full keymap is in [[keymap]], colors/theme are in
[[theming]], terminal/sessions are in [[kitty]] and [[sessions]].

## Key decisions

- **Dwindle layout, gaps and rounding = 0, almost no animations.** A deliberately minimalist
  tiling setup with no visual extras: `gaps_in/out = 0`, `rounding = 0`,
  `animations { enabled = no }` (except utility curves left at default).
  Window borders are a gruvbox gradient (`col.active_border = d8a657 → a9b665`), matching
  the theme.
- **`no_hardware_cursors = true`** — works around a bug with an invisible/corrupted cursor on this
  hardware (comment `fix bag with cursor` in the config). `no_warps` — the cursor doesn't
  jump on focus change.
- **`kb_layout = us,ru`, but layout switching is driven by kanata, not Hyprland.**
  `hyprland-per-window-layout` is running (per-window layout). ⚠️ Gotcha:
  kanata's symbol layers force US xkb — details in [[kanata]]/[[keymap]];
  here only the two layouts are registered.

## Autostart (exec-once)

The order and contents of `exec-once` define "what a working session is":
`kitty` (native sessions, no tmux — see [[kitty]]/[[sessions]]),
`waybar & hyprpaper`, `kanata` (the keyboard engine — critical, no layers without it),
`hyprland-per-window-layout`, `hypridle`, `hyprsunset`, `stretchly`
(break reminders). ⚠️ Gotcha: the browser is NOT in autostart —
`exec-once = browser` was removed (commit `75f46cf`); Firefox comes up lazily
via `workspace = 2, on-created-empty:firefox` on first entering workspace 2.

## Non-trivial bindings (only the "why")

The full map is in [[keymap]]. Here only the non-obvious bits:

- `SUPER, Q` (killactive) is **commented out** in hyprland.conf — killactive is wired up
  via the kanata apps layer (Q under the thumb), see [[keymap]].
- `SUPER, M` — smart exit: `hyprshutdown` if present, otherwise `hyprctl dispatch exit`.
- `SUPER, home` — `systemctl suspend && hyprlock` (manual sleep+lock).
- `SUPER, V` — `copyq toggle` (clipboard manager; the CopyQ window is caught by a windowrule into float).
- `Ctrl-h/j/k/l` window navigation is NOT here — it lives in kitty via `pass_keys.py`
  (contextual: nvim/fzf get them first), see [[kitty]].

## Window rules

- `suppress-maximize-events` for all classes — applications don't "maximize" themselves.
- Telegram → workspace 5, kitty → workspace 1 (stable placement).
- `hyprland-run`/CopyQ — floated with a fixed position.

## idle / lock / suspend

- **hypridle**: the only active listener — `timeout = 1800` (30 min) →
  `systemctl suspend`. Intermediate listeners (dimming, dpms off, an early
  lock) are deliberately commented out. `before_sleep_cmd = loginctl lock-session`
  guarantees a lock BEFORE sleep; `after_sleep_cmd = dpms on` makes the screen wake on
  the first keypress.
- **hyprlock**: background is a blurred screenshot; fields/accents use gruvbox gradients matching
  the window borders. The layout widget is clickable (`hyprctl switchxkblayout all next`).
  Password/colors are hardcoded — the theme doesn't switch here.

## Permissions / env

The `permissions` block (screencopy for grim/portal) is commented out — it runs on
default permissions. Env variables are just cursor sizes (`XCURSOR_SIZE`,
`HYPRCURSOR_SIZE = 24`).

## hyprsunset

Night color temperature, see [[theming]]: day (7:30) — `identity`
(no shift), night (20:00) — `temperature = 6000, gamma = 0.7`. ⚠️ Gotcha: this is
NOT a light/dark app-theme switcher — it's only screen gamma/temperature;
the app theme is set statically (gruvbox dark everywhere).
