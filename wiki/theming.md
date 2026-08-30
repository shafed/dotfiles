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
`telegram/colors.tdesktop-theme` contains the palette and tracked
`telegram/background.jpg` is the preferred botanical Gruvbox wallpaper. The
artwork is inset on a taller dark canvas so Telegram's cover-style wallpaper
scaling crops and zooms it less in a narrow chat pane. Running the generator
packages those as `telegram/gruvbox-material-dark-medium.tdesktop-theme`; the
archive is a local build artifact and is ignored by git. It contains
`colors.tdesktop-theme` and `background.jpg`, which Telegram Desktop reads as the
palette and theme wallpaper. Import the final archive, not the standalone
palette file. The tracked JPEG is passed through as opaque binary data; Telegram
Desktop performs the image decoding, so the generator does not impose its own
JPEG-container validation.

The alternate procedural wallpaper is intentionally retained as a backup. Each
Telegram generation writes it to `telegram/background-backup.png`; that file is
also a local build artifact. The implementation stays in
`telegram/generate-theme.py`, so the backup is reproducible from `colors.toml`
without storing a second large binary in git.

Telegram-specific semantic overrides live in `telegram/generate-theme.py` when
a palette surface has no useful cross-application equivalent. The vertical chat
folder sidebar uses Telegram's `sideBar*` keys explicitly: dark Gruvbox for the
rail and active item, muted foreground for inactive folders, and yellow only for
the active folder and unread badges. This prevents Telegram's built-in blue
sidebar defaults from leaking through the custom theme.

Voice messages also have Telegram-specific overrides. The idle waveform is kept
neutral Gruvbox rather than being used as an unread/read signal. Telegram's
theme API does not expose separate colors for an unread idle voice message and
a listened-but-stopped one: unread media is represented by the small dot after
the duration. That dot shares `msgFileInBg` with the incoming play button, so the
theme makes both yellow to keep the unread marker obvious. Exact whole-message
unread/read recoloring would require patching Telegram Desktop itself.

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
