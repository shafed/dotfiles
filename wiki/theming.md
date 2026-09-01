---
title: theming
type: topic
updated: 2026-09-01
covers:
  - colors.toml
  - scripts/generate-theme.py
  - telegram/
  - darkman/
  - helium/
  - hypr/hyprsunset.conf
  - kitty/current-theme.conf
  - .claude/themes/gruvbox-material.json
  - copyq/gruvbox.ini
  - quickshell/config/Colors.qml
---

# theming — Gruvbox base with solar exceptions

The desktop base uses **Gruvbox Material Dark Medium**, anchored to `#282828`
background / `#d4be98` foreground. Neovim's gruvbox-material setup remains the
visual reference. Most application surfaces stay dark; Telegram, wallpaper and
Helium deliberately react to the solar state in different ways.

## Palette source of truth

`colors.toml` is the only editable repository palette/config source for shared
surfaces:

- `[colors]` — Gruvbox Material Dark Medium used by the tracked desktop
  generators;
- `[colors_light]` — warm-white reference (`#fbfaf7` / `#3c3836`) for browser
  daylight work; Chromium's adaptive theme does not consume these exact values;
- `[helium]` — Chromium User Color seed/variant. Current values are Gruvbox
  warm-neutral `#3c3836`, `neutral`, and `system` color scheme.

After changing shared palette values run:

```sh
python3 scripts/generate-theme.py
python3 scripts/generate-theme.py --check
python3 scripts/generate-theme.py --mode light --check
./dots check
```

The main generator writes Kitty, Waybar, Hyprlock, shell colors, Quickshell,
Claude Code, CopyQ and Yazi surfaces. Those remain pinned dark. Do not hand-edit
generated files.

Claude Code keeps the Gruvbox UI palette, but its six diff colors deliberately
use the dark, high-contrast appearance of Claude's ANSI-style diff (regular and
dimmed added/removed backgrounds, plus stronger word highlights). The explicit
RGB values make that appearance independent of the terminal ANSI palette.

CopyQ deliberately uses the neutral Gruvbox `bg` (`#282828`) as its main surface:
its bundled Font Awesome icons derive tint from the window background, and a
teal-shifted background made those icons visibly blue. The bundled icon set is
kept because system icon themes do not cover all CopyQ actions.

## Telegram

Telegram is independently solar-aware. `telegram/generate-theme.py` builds a
Gruvbox night variant and a warmer olive/taupe day variant. Telegram-specific
daylight values live in that generator rather than recoloring the shared desktop
palette.

The desktop profile keeps one stable runtime path:

```text
$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme
```

Import that file in Telegram and press **Apply Theme** once. Telegram watches the
loaded local theme path, so `darkman/scripts/telegram` can rewrite the same file
between day and night without touching `tdata` or automating UI clicks. See
[telegram](telegram.md) for bootstrap details.

The botanical wallpaper source is stored as text-safe
`telegram/background.png.b64`, decoded locally and embedded into both variants.
PNG is intentional because an older JPEG source was corrupted in git history and
failed strict Telegram decoding. The procedural backup remains reproducible from
the generator.

Telegram's theme API cannot independently recolor an unread stopped voice message
versus a listened stopped message; the unread state is the small duration dot.
The theme therefore keeps the waveform neutral and uses the active variant's
accent for the shared play-button/unread-dot surface.

## Helium: native User Color, not an extension theme

The old Helium implementation used an unpacked Chromium theme extension with a
`manifest.json`. That gives exact RGB control but is static: changing its colors
requires Chromium to rebuild/reload compiled theme state, so reliable dark/light
switching needs a browser restart. It also flattens part of Helium's native
active/inactive vertical-tab treatment.

The current implementation instead uses Chromium's built-in **User Color** theme.
On Linux Helium's upstream user-data directory is
`$XDG_CONFIG_HOME/net.imput.helium`. `helium/apply-gruvbox-theme.py` reads
`Local State` there and updates the active profile's `Preferences` (falling back
to `Default`). An explicit persistent `--user-data-dir=...` takes precedence.
The desired state is the semantic equivalent of:

```text
extensions.theme.id = user_color_theme_id
browser.theme.user_color{,2} = #3c3836
browser.theme.color_variant{,2} = neutral
browser.theme.color_scheme{,2} = system
browser.theme.follows_system_colors = false
```

Both the deprecated and current `*2` preference names are written because recent
Chromium revisions are migrating those prefs. The deterministic profile state
keeps `follows_system_colors=false`; Linux light/dark following itself comes from
`color_scheme=system` and Chromium's native appearance signal.

This is intentionally **Gruvbox-derived, not exact Gruvbox surfaces**. Chromium's
Material color generator owns final light/dark shades. Helium's vertical-tab
frame resolves through Chromium's native frame/header colors. For a themed User
Color palette, the header is generated from the secondary tonal palette; even the
`neutral` variant fixes that palette to a small non-zero chroma. Consequently,
seed saturation is not a useful way to remove a cast from the whole sidebar —
the seed hue is the important lever.

The earlier yellow seed `#b47109` therefore produced a visibly cream/brown frame
(`~#fff8f4` light and `~#271e14` dark on the tested Helium build). The current
seed uses Gruvbox `bg_soft` (`#3c3836`) instead: its warm-neutral hue keeps the
native generated surfaces closer to the original neutral Gruvbox treatment while
retaining native tab-state styling and live system-mode repainting.

### Why Helium switches live

Darkman already publishes `org.freedesktop.appearance/color-scheme` through the
XDG Desktop Portal. Current Chromium on Linux feeds that appearance signal into
its native theme/ColorProvider path. With browser scheme set to `System`, the
runtime path is:

```text
darkman -> XDG appearance portal -> Chromium NativeTheme/ColorProvider -> repaint
```

There is therefore **no Helium-specific darkman hook** and no
`--force-light-mode` / `--force-dark-mode` launch flag. `dots theme light`,
`dots theme dark`, automatic sunrise and automatic sunset all use the same portal
signal and should update an already-running Helium.

### One-time migration from the unpacked theme

Helium writes `Preferences` on shutdown, so the first migration must not edit a
running profile. Close Helium once and run:

```sh
./dots apply
```

The generator then:

- discovers the active profile from `net.imput.helium/Local State`;
- selects Chromium's special `user_color_theme_id`;
- sets the Gruvbox seed, Neutral variant and System scheme;
- removes dotfiles-owned Gruvbox `--load-extension`, both old managed blocks and
  stray standalone `--force-light-mode` / `--force-dark-mode` lines while
  preserving unrelated browser flags/extensions;
- removes the old dotfiles-owned `helium-gruvbox`, `helium-gruvbox-dark` and
  `helium-gruvbox-light` runtime directories.

Start Helium once after that migration. This one restart activates the changed
profile preferences; **later light/dark transitions do not require a restart**.
Changing the User Color seed is likewise a profile preference change: close
Helium for `dots apply` once, then subsequent solar transitions stay live.

If Helium has never created an active `Preferences`, `dots apply` does not invent
a browser profile. Launch Helium once, close it, and apply again.

### Verification

First resolve the active profile the same way Chromium does:

```sh
HELIUM_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/net.imput.helium"
PROFILE="$(jq -r '.profile.last_used // "Default"' "$HELIUM_ROOT/Local State")"
PREFS="$HELIUM_ROOT/$PROFILE/Preferences"
echo "$PREFS"
```

Then check the built-in theme state:

```sh
jq '{
  id: .extensions.theme.id,
  scheme: .browser.theme.color_scheme2,
  seed: .browser.theme.user_color2,
  variant: .browser.theme.color_variant2,
  follows_os_accent: .browser.theme.follows_system_colors
}' "$PREFS"
```

Expected semantic values:

```text
id = user_color_theme_id
scheme = 0   # System
seed = -12830666   # signed SkColor for #3c3836
variant = 2  # Neutral
follows_os_accent = false
```

The legacy flags check should print nothing:

```sh
grep -E 'helium-gruvbox|force-(light|dark)-mode' \
  ~/.config/helium-browser-flags.conf
```

Check the portal itself when live switching is suspect:

```sh
gdbus call --session \
  --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.ReadOne \
  org.freedesktop.appearance color-scheme
```

The XDG values are `1 = dark`, `2 = light`. Run `dots theme toggle`; the Helium
chrome and web `prefers-color-scheme` should follow without restarting.

## Light/dark scope

GTK, Kitty, Hyprlock, Waybar, Quickshell, Yazi, CopyQ and Claude Code stay pinned
dark. The GTK darkman hook always keeps a dark GTK theme; Helium does **not** use
that GTK theme as its light/dark source. Its authoritative source is the XDG
appearance portal.

Solar-state exceptions are:

1. Hyprland wallpaper — `darkman/scripts/wallpaper` switches light/dark images
   through hyprpaper IPC;
2. Telegram — `darkman/scripts/telegram` rewrites the stable watched theme file;
3. Helium — Chromium itself follows the portal with the built-in adaptive User
   Color theme.

`hypr/hyprsunset.conf` is independent gamma/temperature control.

### Stale darkman directory

`darkman/scripts` is symlinked wholesale to `$XDG_DATA_HOME/darkman`; darkman
scans that directory's entries directly. An older machine may have a real
`~/.local/share/darkman` directory with unmanaged hooks. `dots doctor` reports
that mismatch and `dots migrate` backs it up/removes it so `dots apply` can
install the tracked symlink.
