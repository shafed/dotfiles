---
title: theming
type: topic
updated: 2026-08-14
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

darkman flips the GTK/Qt `color-scheme` preference at sunrise/sundown. Modern
GTK and Qt apps honor that preference and render their own dark/light variant,
which is why no per-app theme files exist for them.

- ⚠️ **Hooks live in the XDG *data* dir, not `~/.config`.** darkman v2 only
  scans `$XDG_DATA_HOME/darkman/` (+ `XDG_DATA_DIRS`) for transition scripts,
  hence the `~/.local/share/darkman → ~/dotfiles/darkman/scripts` symlink from
  `bootstrap.sh`. A hook placed in `~/.config` is silently never run.
- **kitty is intentionally NOT toggled** — it keeps its single gruvbox-dark
  `current-theme.conf`.
- ⚠️ **Gaps**: waybar/yazi/nvim are static gruvbox dark and don't follow the
  color-scheme; only GTK/Qt apps do. To widen the switch, add per-app hooks to
  `darkman/scripts/`.

## hyprsunset — screen gamma/temperature only

⚠️ Don't confuse `hypr/hyprsunset.conf` with theme switching: it is an
independent night filter over the whole screen, does NOT touch app colors, and
is NOT linked to darkman.
