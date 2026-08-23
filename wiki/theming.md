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

Everything is **Gruvbox Material Dark Medium**, anchored to `background #282828`
/ `foreground #d4be98`. **nvim is the reference** — kitty's background was tuned
to match it, not the other way round.

⚠️ Gotcha: **there is no source-of-truth color file.** The palette is
hand-duplicated in seven places, and changing a shade means editing all of them:

- `kitty/current-theme.conf`, plus a second copy in
  `quick-access-terminal-center.conf` via `kitty_override`
- `waybar/style.css` (`@define-color gb_*`)
- `yazi/flavors/gruvbox-dark.yazi` + `theme.toml`
- nvim's own gruvbox-material plugin
- `.claude/themes/gruvbox-material.json`
- hyprland/hyprlock — raw hex in the configs for borders and lock fields

The Claude Code theme deliberately leaves `claudeShimmer` at its built-in color:
overriding it made the thinking animation harder to pick out. The base `claude`
accent and the rest of that UI are gruvbox.

## Light/dark: darkman toggles the system color-scheme, not kitty

darkman flips the GTK/Qt `color-scheme` preference at sunrise/sundown. Modern
GTK and Qt apps honor that preference and render their own dark/light variant,
which is why no per-app theme files exist for them.

- ⚠️ **Hooks live in the XDG *data* dir, not `~/.config`.** darkman v2 only
  scans `$XDG_DATA_HOME/darkman/` (+ `XDG_DATA_DIRS`) for transition scripts,
  hence the `~/.local/share/darkman → ~/github/dotfiles/darkman/scripts` symlink from
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
