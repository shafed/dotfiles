---
title: theming
type: topic
updated: 2026-08-10
covers:
  - darkman/
  - hypr/hyprsunset.conf
  - kitty/current-theme.conf
  - .claude/themes/gruvbox-material.json
---

# theming — gruvbox (dark everywhere)

End-to-end visual theme. Components: [kitty](kitty.md), [waybar](waybar.md),
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
- `.claude/themes/gruvbox-material.json` — Claude Code's theme (custom
  overrides, "custom:gruvbox-material"), symlinked to `~/.claude/themes/` by
  `bootstrap.sh`. Its thinking shimmer deliberately keeps Claude Code's
  built-in color: overriding `claudeShimmer` made the animation harder to
  distinguish, while the base `claude` accent and the rest of the UI stay gruvbox,
- hyprland/hyprlock — hex colors for borders/fields directly in configs (`d8a657`, `a9b665`…).

Change a shade — edit ALL of these places, there's no automatic sync.

## Light/dark: darkman toggles the system color-scheme, not kitty

- **darkman** runs as a systemd user service (`systemd/user/darkman.service`,
  `Type=dbus`, `BusName=nl.whynothugo.darkman`). It auto-transitions at
  sunrise/sundown using static Moscow coordinates (`darkman/config.yaml`,
  `usegeoclue: false`); day = light, night = dark.
- **Hooks live in the XDG *data* dir, not `~/.config`.** darkman v2 only scans
  `$XDG_DATA_HOME/darkman/` (+ `XDG_DATA_DIRS`) for transition scripts.
  `~/.local/share/darkman → ~/dotfiles/darkman/scripts` (symlink created by
  `bootstrap.sh`). The unified script `darkman/scripts/gtk` takes the mode as
  `$1` (`dark`/`light`) and sets
  `gsettings org.gnome.desktop.interface color-scheme` to `prefer-dark`/
  `prefer-light`. Modern GTK (built-in Adwaita) and Qt apps honor this and render
  their dark/light variant, so no separate theme files are needed.
- **kitty is intentionally NOT toggled** — the terminal keeps its single
  gruvbox-dark `current-theme.conf` (included from `kitty.conf:3015`).
- ⚠️ **Gaps**: waybar/yazi/nvim are static gruvbox dark and don't follow the
  color-scheme; only GTK/Qt apps do. To widen the switch, add per-app hooks to
  `darkman/scripts/`.

## hyprsunset — screen gamma/temperature only

`hypr/hyprsunset.conf` controls display color temperature by time of day (day
7:30 — `identity`; night 20:00 — `temperature 6000, gamma 0.7`), started from
`exec-once` in [hypr](hypr.md). ⚠️ Don't confuse with theme switching: hyprsunset does NOT
touch app colors and is NOT linked to darkman — it's an independent night filter
over the whole screen.

## Summary for the agent

Base theme is static gruvbox dark (kitty/waybar/yazi/nvim). darkman (systemd
user service + data-dir hook `darkman/scripts/gtk`) toggles the GTK/Qt
`color-scheme` preference (dark/light), affecting system apps — kitty is left
untouched. hyprsunset is a separate gamma/temperature night filter, independent
of darkman.
