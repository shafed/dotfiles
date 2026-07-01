---
title: theming
type: topic
updated: 2026-07-01
covers:
  - darkman/
  - hypr/hyprsunset.conf
  - kitty/current-theme.conf
---

# theming — gruvbox (dark everywhere)

🚧 End-to-end visual theme. Components: [kitty](kitty.md), [waybar](waybar.md),
[yazi](yazi.md), [hypr](hypr.md), nvim ([nvim](nvim.md)).

## One visual language: Gruvbox Material Dark

Same palette everywhere — **Gruvbox Material Dark Medium**, anchored to
`background #282828` / `foreground #d4be98`. Reference point is nvim; the kitty
background was specifically tuned to match it (`e5557fc`: hard→medium `#282828`),
terminal colors aligned to gruvbox material (`1a43177`, `81ce442`).

⚠️ Gotcha: **there is no single source-of-truth color file.** The palette is
duplicated across components by hand:

- `kitty/current-theme.conf` (+ a duplicate in `quick-access-terminal-center.conf` via
  `kitty_override`),
- `waybar/style.css` (`@define-color gb_*`),
- `yazi/flavors/gruvbox-dark.yazi` + `theme.toml`,
- nvim — its own gruvbox-material plugin,
- hyprland/hyprlock — hex colors for borders/fields directly in configs (`d8a657`, `a9b665`…).

Change a shade — edit ALL of these places, there's no automatic sync.

## Light/dark: effectively always dark

- **yazi**: `theme.toml` — both `dark` and `light` point to `gruvbox-dark`
  (no switching happens).
- **darkman**: installed (`darkman/config.yaml`: `usegeoclue: false`, Moscow
  `lat/lng` coordinates for sunset calculation), BUT ⚠️ **`darkman/scripts/` is empty** — no
  dark-mode.d or light-mode.d hooks, and darkman isn't mentioned anywhere else in the repo
  and isn't in Hyprland autostart. So the app theme-switching mechanism is
  de facto NOT wired up — a placeholder for the future, not a working switcher.

## hyprsunset — screen gamma/temperature only

`hypr/hyprsunset.conf` controls display color temperature by time of day (day
7:30 — `identity`; night 20:00 — `temperature 6000, gamma 0.7`), started from
`exec-once` in [hypr](hypr.md). ⚠️ Don't confuse with theme switching: hyprsunset does NOT
touch app colors and is NOT linked to darkman — it's an independent night filter
over the whole screen.

## Summary for the agent

The theme is static: gruvbox dark, set via a copy in each component. There's no
dynamic light/dark pipeline right now (darkman scaffolding is empty; hyprsunset is a
separate gamma correction).
