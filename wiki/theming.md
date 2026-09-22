---
title: theming
type: topic
updated: 2026-09-22
covers:
  - colors.toml
  - scripts/generate-theme.py
  - telegram/
  - darkman/
  - hypr/hyprsunset.conf
  - kitty/current-theme.conf
  - .claude/themes/gruvbox-material.json
  - .opencode/themes/gruvbox-material.json
  - codex/themes/gruvbox-material.tmTheme
  - copyq/gruvbox.ini
  - quickshell/config/Colors.qml
---

# theming — Gruvbox base with solar exceptions

The desktop base uses **Gruvbox Material Dark Medium**, anchored to `#282828`
background / `#d4be98` foreground. Neovim's gruvbox-material setup remains the
visual reference. Most application surfaces stay dark; GTK, Telegram, wallpaper
and Helium deliberately react to the solar state.

## Palette source of truth

`colors.toml` is the editable palette source:

- `[colors]` — Gruvbox Material Dark Medium used by the desktop;
- `[colors_light]` — warm Gruvbox daylight palette, validated but currently
  without a generated consumer.

After changing shared palette values run:

```sh
python3 scripts/generate-theme.py
python3 scripts/generate-theme.py --check
python3 scripts/generate-theme.py --mode light --check
./dots check
```

The main generator writes Kitty, Waybar, Hyprlock, shell colors, Quickshell,
Claude Code, Codex, opencode, CopyQ and Yazi surfaces. Those remain pinned dark.
Codex reads the generated TextMate theme from `~/.codex/themes/` through the
base-profile symlink. Set `tui.theme = "gruvbox-material"` in the mutable user
`~/.codex/config.toml` (or choose it with `/theme`). Codex applies this palette
to syntax highlighting in code blocks and diffs; the theme does not define a
complete UI palette.
opencode's theme keys are plain string references into the generated `defs`
block (which mirrors `colors.toml` verbatim) rather than `{dark, light}` pairs,
matching the dark-only convention here; `.opencode/tui.json` is a small static
file (not generated) that selects `"theme": "gruvbox-material"`.

Claude Code keeps the Gruvbox UI palette, but its six diff colors deliberately
use the dark, high-contrast appearance of Claude's ANSI-style diff (regular and
dimmed added/removed backgrounds, plus stronger word highlights). The explicit
RGB values make that appearance independent of the terminal ANSI palette.

CopyQ deliberately uses the neutral Gruvbox `bg` (`#282828`) as its main surface:
its bundled Font Awesome icons derive tint from the window background, and a
teal-shifted background made those icons visibly blue. The bundled icon set is
kept because system icon themes do not cover all CopyQ actions.

CopyQ owns `copyq.conf` as mutable runtime state and rewrites loaded multi-line
CSS as quoted values containing literal `\n` escapes. The live-theme merger emits
that same representation and replaces existing managed keys in place; otherwise
CopyQ's normal save would create permanent generator drift after every apply.

## Telegram

Telegram is independently solar-aware. `telegram/generate-theme.py` builds a
Gruvbox night variant and a warmer olive/taupe day variant. Telegram-specific
daylight values live in that generator rather than recoloring the shared desktop
palette.

The file imported manually in Telegram is generated inside the repository:

```text
telegram/current.tdesktop-theme
```

It is gitignored build/runtime state. The wrapper also keeps
`$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme` as a profile-state
mirror so `dots plan/apply` can verify deterministic generator output without
managing a generated file in the checkout. Import the repository copy and press
**Apply Theme** once. Telegram watches that local path, so
`darkman/scripts/telegram` rewrites the same inode between day and night without
touching `tdata` or automating UI clicks. See [telegram](telegram.md) for
bootstrap details.

The wallpaper source is the tracked binary `telegram/background.png`. The
Telegram generator embeds that PNG verbatim into both variants; it does not
create, recolor, decode, or retain alternate/backup wallpapers. Replacing this
single file and running `./dots apply` or switching the Telegram solar state is
the supported way to change the chat background.

Telegram's theme API cannot independently recolor an unread stopped voice message
versus a listened stopped message; the unread state is the small duration dot.
Playback progress therefore carries the stronger semantic contrast instead:
incoming played waveform is yellow, outgoing played waveform is aqua, selected
states use their paired orange/blue accents, and the unplayed part stays neutral
gray.

## Helium: default theme

Helium uses Chromium's **default** theme (profile pref
`extensions.theme.system_theme = 0`, no extension theme). It does not follow the
GTK theme or the solar state, and dots does not manage Helium's `Preferences`.
GTK mode (Settings → Appearance → Theme → GTK) recolors it live from
`darkman/scripts/gtk`, but it is not enabled.

### Why not an extension theme (removed 2026-09-16; GTK mode dropped later)

Helium used to load exact Gruvbox extension-theme manifests and reload them on
darkman transitions through CDP (`Extensions.loadUnpacked`). That required a
permanent `--remote-debugging-port` launch flag, and **an open DevTools port
makes Cloudflare's bot check fail in a loop** (claude.ai never passed). Verified:
a clean profile with only `--load-extension` passed; the port was the trigger.

There is no CDP-free way to recolor an extension theme live, verified with a
native-messaging helper extension using `chrome.management`:

- `setEnabled(true)` on an already-enabled theme does nothing, and Chromium keeps
  only one theme installed — a second loaded theme is removed;
- disabling and re-enabling a theme does not re-read its `manifest.json` from
  disk;
- `chrome.theme.update()` exists only in Firefox.

Do not reintroduce `--remote-debugging-port` in `helium-browser-flags.conf`.

## Light/dark scope

GTK now follows the solar state: `darkman/scripts/gtk` applies an installed
Gruvbox dark theme (falling back to `Adwaita-dark`) in dark mode, and
stock `Adwaita` with `prefer-light` in light mode (no custom light GTK theme).
Helium keeps its default theme. Kitty, Hyprlock, Waybar,
Quickshell, Yazi, CopyQ and Claude Code stay pinned dark. Other solar-state
exceptions are:

1. Hyprland wallpaper — `darkman/scripts/wallpaper` switches light/dark images
   through hyprpaper IPC;
2. Telegram — `darkman/scripts/telegram` rewrites the stable watched theme file.

`hypr/hyprsunset.conf` is independent gamma/temperature control.

### Stale darkman directory

`darkman/scripts` is symlinked wholesale to `$XDG_DATA_HOME/darkman`; darkman
scans that directory's entries directly. An older machine may have a real
`~/.local/share/darkman` directory with unmanaged hooks. `dots doctor` reports
that mismatch and `dots migrate` backs it up/removes it so `dots apply` can
install the tracked symlink.
