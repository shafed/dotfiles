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
Helium deliberately react to the solar state.

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

### First setup versus later transitions

Run:

```sh
./dots apply
```

Then restart Helium **once** so the new startup flags exist in the browser
process. That single restart is unavoidable: `--load-extension` and
`--remote-debugging-port` are launch flags, and CDP — the only live-reload
channel — cannot be enabled on an already-running Chromium. Every switch after
it, including the first one following any later restart, needs no restart:

```sh
./dots theme light
./dots theme dark
./dots theme toggle
```

Sunrise and sunset use the same darkman hook. If live CDP reload is unavailable,
the switcher still updates the runtime manifest and reports a deferred reload;
restarting Helium then loads the already-correct variant.

### Exact color mapping

Dark uses the repository's Gruvbox Material Dark palette, including:

```text
frame/sidebar    #1d2021
toolbar surface  #3c3836
omnibox/NTP      #282828
text             #d4be98
```

Light uses the daylight palette:

```text
frame/sidebar    #f2efe8
toolbar surface  #ece9e2
omnibox/NTP      #fbfaf7
text             #3c3836
```

Chromium extension themes still cannot independently address every Helium
vertical-tab Material role. In particular, the active-tab treatment may be less
distinct than Helium's native generated theme. Exact palette switching and native
per-role tab styling are separate constraints; solving the latter would require a
change inside Helium/Chromium rather than another manifest color key.

### Verification

Check the selected solar mode and runtime theme:

```sh
darkman get
jq '{name, frame: .theme.colors.frame, toolbar: .theme.colors.toolbar, omnibox: .theme.colors.omnibox_background}' \
  ~/.local/share/dotfiles/helium-gruvbox/manifest.json
```

Check the managed startup state:

```sh
grep -E 'load-extension|remote-debugging-port|force-(light|dark)-mode|install-autogenerated-theme' \
  ~/.config/helium-browser-flags.conf
```

Expected: the stable `helium-gruvbox` load-extension path and a remote debugging
port setting; no force-light/dark or autogenerated-theme flag.

After Helium has been restarted once, this should exist while it is running:

```sh
cat ~/.config/net.imput.helium/DevToolsActivePort
```

For a direct switch test independent of darkman's scheduler:

```sh
python3 helium/switch-gruvbox-theme.py light
python3 helium/switch-gruvbox-theme.py dark
```

## Light/dark scope

GTK, Kitty, Hyprlock, Waybar, Quickshell, Yazi, CopyQ and Claude Code stay pinned
dark. Solar-state exceptions are:

1. Hyprland wallpaper — `darkman/scripts/wallpaper` switches light/dark images
   through hyprpaper IPC;
2. Telegram — `darkman/scripts/telegram` rewrites the stable watched theme file;
3. Helium — `darkman/scripts/helium` rewrites and reloads the exact unpacked
   Gruvbox theme.

`hypr/hyprsunset.conf` is independent gamma/temperature control.

### Stale darkman directory

`darkman/scripts` is symlinked wholesale to `$XDG_DATA_HOME/darkman`; darkman
scans that directory's entries directly. An older machine may have a real
`~/.local/share/darkman` directory with unmanaged hooks. `dots doctor` reports
that mismatch and `dots migrate` backs it up/removes it so `dots apply` can
install the tracked symlink.
