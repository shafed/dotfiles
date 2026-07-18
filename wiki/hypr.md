---
title: hypr
type: component
updated: 2026-07-18
covers:
  - hypr/hyprland.conf
  - hypr/hypridle.conf
  - hypr/hyprlock.conf
  - hypr/hyprsunset.conf
---

# hypr

🚧 The compositor (Wayland). The full keymap is in [keymap](keymap.md), colors/theme are in
[theming](theming.md), terminal/sessions are in [kitty](kitty.md) and [sessions](sessions.md).

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
  kanata's symbol layers force US xkb — details in [kanata](kanata.md)/[keymap](keymap.md);
  here only the two layouts are registered.

## Autostart (exec-once)

The order and contents of `exec-once` define "what a working session is":
`kitty` (native sessions, no tmux — see [kitty](kitty.md)/[sessions](sessions.md)),
`waybar & hyprpaper`, `hyprland-per-window-layout`, `hypridle`, `hyprsunset`,
`stretchly` (break reminders). ⚠️ Gotcha: the browser is NOT in autostart —
`exec-once = browser` was removed (commit `75f46cf`); Helium comes up lazily
via `workspace = 2, on-created-empty:helium-browser` on first entering
workspace 2. The measured Hyprland class is `helium`, which is what the
browser helpers in [scripts](scripts.md) use for focus/move rules.

kanata is **not** started here anymore — it moved to a systemd user service
(`../systemd/user/kanata.service`, `WantedBy=default.target`) so it starts at
login independent of the compositor and restarts on crash. See
[kanata](kanata.md).

## Session launch: uwsm

Hyprland is launched via `uwsm start hyprland-uwsm.desktop` from
`../zsh/zprofile` (see [bootstrap](bootstrap.md)), not the raw `start-hyprland`
binary. Reason: Hyprland itself never activates `graphical-session.target`, so
without uwsm the systemd user manager never learns
`WAYLAND_DISPLAY`/`DISPLAY`, and user services that need the Wayland session
(e.g. `adrop.service`, see `../systemd/user/adrop.service`) start with a broken
environment. uwsm imports the session environment and drives
`graphical-session.target` itself, so the previous manual workaround in
hyprland.conf
(`exec-once = systemctl --user import-environment ... && systemctl --user restart adrop.service`)
was removed — no longer needed.

⚠️ Gotcha: this only protects services that actually order themselves after
`graphical-session.target`. A `WantedBy=default.target` unit with no `After=`
can still start in the same instant `default.target` is reached, racing
uwsm's environment import — `copyq.service` did exactly this (crash-looped on
"no Qt platform plugin" until it hit systemd's start-limit) until
`After=graphical-session.target` was added, matching `kanata.service`. Any
user service that touches the Wayland/X11 session needs that `After=` line,
not just `WantedBy=default.target`.

## Non-trivial bindings (only the "why")

The full map is in [keymap](keymap.md). Here only the non-obvious bits:

- `SUPER, Q` (killactive) is **commented out** in hyprland.conf — killactive is wired up
  via the kanata apps layer (Q under the thumb), see [keymap](keymap.md).
- `SUPER, M` — smart exit: `hyprshutdown` if present, otherwise `hyprctl dispatch exit`.
- `SUPER, home` — `systemctl suspend && hyprlock` (manual sleep+lock).
- `SUPER, V` — `copyq toggle` (clipboard manager; the CopyQ window is caught by a windowrule into float).
- `SUPER, N` — `nvim-scratch-toggle.sh`: floating kitty+nvim scratch note (QAT
  panel, not a special workspace/windowrule) that pastes itself into whatever
  was focused before it opened once you quit nvim. Details in
  [scripts](scripts.md).
- `Ctrl-h/j/k/l` window navigation is NOT here — it lives in kitty via `pass_keys.py`
  (contextual: nvim/fzf get them first), see [kitty](kitty.md).

## Window rules

- `suppress-maximize-events` for all classes — applications don't "maximize" themselves.
- Telegram → workspace 5, kitty → workspace 1 (stable placement).
- `hyprland-run`/CopyQ — floated with a fixed position.
- `com.gabm.satty` (screenshot annotation, see [kanata](kanata.md)) — floated at
  `95% 95%`, centered; without this it tiles into the dwindle layout at a small
  size instead of taking most of the screen.

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

Night color temperature, see [theming](theming.md): day (7:30) — `identity`
(no shift), night (20:00) — `temperature = 6000, gamma = 0.7`. ⚠️ Gotcha: this is
NOT a light/dark app-theme switcher — it's only screen gamma/temperature;
the app theme is set statically (gruvbox dark everywhere).
