---
title: theming
type: topic
updated: 2026-09-02
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
visual reference. Most application surfaces stay dark; GTK, Telegram, wallpaper
and Helium deliberately react to the solar state.

## Palette source of truth

`colors.toml` is the editable palette source:

- `[colors]` — Gruvbox Material Dark Medium used by the desktop and Helium dark;
- `[colors_light]` — exact warm Gruvbox daylight palette used by Helium light.

After changing shared palette values run:

```sh
python3 scripts/generate-theme.py
python3 scripts/generate-theme.py --check
python3 scripts/generate-theme.py --mode light --check
python3 tests/helium-theme.py
./dots check
```

The main generator writes Kitty, Waybar, Hyprlock, shell colors, Quickshell,
Claude Code, CopyQ and Yazi surfaces. Those remain pinned dark. Helium's two
Chromium manifests are separate protocol mappings of `[colors]` and
`[colors_light]`; `tests/helium-theme.py` guards their exact mapped colors.

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

## Helium: exact Gruvbox light/dark extension theme

Helium now uses exact Chromium extension-theme manifests rather than Chromium's
User Color generator:

```text
helium/gruvbox-dark/manifest.json
helium/gruvbox-light/manifest.json
```

The reason is precision. Chromium User Color can follow System mode live, but it
owns the final tonal palette and therefore only approximates Gruvbox. A Chromium
theme extension can specify the actual RGB values. The runtime therefore combines
exact extension colors with a small darkman-driven reload mechanism.

### Vertical tab strip: why the active tab has no fill of its own

Helium runs a vertical tab strip, and there the strip background and the active
tab are painted from the **same** Chromium theme key, `toolbar`. Only the
unselected tabs have a key of their own, `background_tab`. Verified by loading a
probe manifest with `frame` red, `toolbar` green and `background_tab` magenta:
the strip and the active tab both came out pure green, `frame` was not used
anywhere, and `omnibox_background` / `ntp_header` / `button_background` were not
used either. A `theme_toolbar` image behaves the same way — it fills the strip
and the active tab together.

So an extension theme cannot give the active tab its own fill. Whatever differs
from the strip is the *unselected* tabs, which is why they used to be the ones
that looked highlighted. The manifests therefore set

```text
background_tab == background_tab_inactive == toolbar
```

so unselected tabs disappear into the strip, and mark the active tab by text
instead: `tab_text` is `fg_bright` (`#1d2021` / `#fbf1c7`) against
`tab_background_text` `gray` (`#928374`). One accepted cost: the hover highlight
is derived as a blend of `background_tab` and `toolbar`, so making them equal
also removes it.

Helium's *default* theme does show a filled active tab (light mode: `#ffffff`
strip, `#e8e8e8` active tab). That is not reproducible here — it comes from
Chromium's generated Material 3 palette, where the strip and the active tab are
separate roles, and installing any theme extension collapses both onto
`toolbar`. Getting that look back would mean returning to the User Color
generator and giving up exact RGB values.

The stable runtime path is:

```text
$XDG_DATA_HOME/dotfiles/helium-gruvbox/manifest.json
```

`helium/switch-gruvbox-theme.py` rewrites that manifest from the tracked dark or
light variant. `darkman/scripts/helium` receives `dark` / `light` and invokes the
switcher. If Helium is closed, that is enough: the next browser start loads the
correct manifest.

### Live switching in a running Helium

A loaded Chromium theme is static; rewriting its `manifest.json` alone does not
make Chromium rebuild the theme. To reload the same unpacked theme without
restarting Helium, `dots apply` adds two managed launch flags:

```text
--load-extension=$XDG_DATA_HOME/dotfiles/helium-gruvbox
--remote-debugging-port=0
```

The actual `--load-extension` path is written through the existing
`/home/./user/...` workaround because `helium-browser-bin`'s Arch wrapper can
otherwise turn a home-directory absolute path into an unusable literal `~` path.

With `--remote-debugging-port=0`, Chromium writes its loopback DevTools endpoint
to the active user-data directory's `DevToolsActivePort`. On a darkman transition
the switcher connects locally to the browser-level DevTools WebSocket and calls
`Extensions.loadUnpacked` on the stable runtime path — one call, which re-reads
`manifest.json` from disk and keeps the same extension id, so it both installs
and refreshes the theme.

That call is deliberately **not** preceded by `Extensions.uninstall`. Chromium
refuses to uninstall an extension that came from `--load-extension`, which is
exactly its state after every Helium restart, so uninstalling first made the
first switch after each start fail and demand yet another restart — an endless
loop. Reload failures also name their cause instead of silently printing
"restart Helium", because that message hid real CDP errors.

No Helium source patch or profile `Preferences` edit is involved. The endpoint is
only needed because extension themes otherwise have no live color-reload API.
It is a local debugging surface, so do not expose its port outside localhost.
