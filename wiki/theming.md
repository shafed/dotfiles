---
title: theming
type: topic
updated: 2026-08-30
covers:
  - colors.toml
  - scripts/generate-theme.py
  - telegram/
  - darkman/
  - hypr/hyprsunset.conf
  - kitty/current-theme.conf
  - .claude/themes/gruvbox-material.json
  - quickshell/config/Colors.qml
---

# theming — gruvbox (dark everywhere)

Everything uses **Gruvbox Material Dark Medium**, anchored to `#282828`
background / `#d4be98` foreground. Neovim's gruvbox-material setup remains the
visual reference.

## Palette source of truth

`colors.toml` is the only editable repository palette. After changing it, run:

```sh
python3 scripts/generate-theme.py
python3 scripts/generate-theme.py --check
python3 telegram/generate-theme.py
python3 telegram/generate-theme.py --check
```

The main generator writes the tracked format-specific surfaces:

- `kitty/current-theme.conf` and `kitty/quick-access-terminal-center.conf`;
- `waybar/colors.css` (imported by `style.css`);
- `hypr/colors.conf` (sourced by `hyprlock.conf`);
- `scripts/generated-colors.sh` (available to shell consumers);
- `quickshell/config/Colors.qml`;
- `.claude/themes/gruvbox-material.json`;
- `yazi/flavors/gruvbox-dark.yazi/flavor.toml`.

Telegram Desktop is user-imported rather than symlinked by bootstrap, so its
surface is generated separately by `telegram/generate-theme.py`. The tracked
`telegram/colors.tdesktop-theme` contains the palette and
`telegram/background.jpg` contains the low-contrast Gruvbox wallpaper. Running
the generator packages both as
`telegram/gruvbox-material-dark-medium.tdesktop-theme`; the archive is a local
build artifact and is ignored by git. Open that file in Telegram Desktop and
choose **Apply this theme**. The bundled file contains `colors.tdesktop-theme`
and `background.jpg`, which are the names Telegram Desktop expects inside a
`.tdesktop-theme` ZIP.

Do not hand-edit color values in generated files. Configs listed above consume
generated palette surfaces rather than maintaining independent values. Yazi's
existing classic-Gruvbox accents are intentionally preserved as compatibility
entries in `colors.toml`; regeneration therefore does not restyle Yazi. Its
vendored `tmtheme.xml` is syntax-highlighting metadata from the upstream flavor
and is not used as the desktop palette source.

The Claude Code theme deliberately leaves `claudeShimmer` at its built-in color;
overriding it made the thinking animation harder to distinguish.

The previously documented unpacked Helium theme is no longer present in the
repository. Helium therefore is not a generated target here.

## Light/dark

Darkman flips the GTK/Qt `color-scheme` preference at sunrise/sundown. It does
not rewrite static dotfile palettes. Hooks live in the XDG data dir
(`~/.local/share/darkman` via bootstrap), not `~/.config`.

`hypr/hyprsunset.conf` is independent screen gamma/temperature control and does
not switch application themes.
