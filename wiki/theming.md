---
title: theming
type: topic
updated: 2026-08-31
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

# theming — Gruvbox base with a Telegram daylight exception

The desktop base uses **Gruvbox Material Dark Medium**, anchored to `#282828`
background / `#d4be98` foreground. Neovim's gruvbox-material setup remains the
visual reference. Telegram is the deliberate exception: its `light` solar state
uses a warmer olive/taupe palette for daylight readability while its `dark`
state stays Gruvbox.

## Palette source of truth

`colors.toml` is the only editable repository palette for shared surfaces. After
changing it, run:

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
- `copyq/gruvbox.ini` (applied to CopyQ's mutable live config by
  `scripts/copyq-apply-theme.py`, which also enforces the repo-owned behavior
  options);
- `yazi/flavors/gruvbox-dark.yazi/flavor.toml`.

CopyQ keeps its complete bundled Font Awesome toolbar set because the available
system icon themes only cover some of its action names. CopyQ derives the icon
tint from the window background rather than the theme foreground; using the
slightly teal `bg_hard` amplifies that hue into blue icons. Its surface therefore
uses the neutral Gruvbox `bg` (`#282828`), which makes the derived icons neutral
gray while preserving Gruvbox hover, selection, and foreground colors.

Telegram Desktop is generated separately by `telegram/generate-theme.py`. The
night variant comes from the shared Gruvbox palette, while the day variant
re-maps Telegram's whole local alias layer to muted olive/taupe surfaces and
warmer accents. These Telegram-only daylight values stay in the Telegram
generator rather than `colors.toml`, because the readability problem is specific
to its dense chat UI and should not recolor the rest of the desktop.

The preferred botanical wallpaper is stored as text-safe
`telegram/background.png.b64`; the generator decodes it to local
`telegram/background-primary.png` and embeds the decoded bytes in both generated
variant archives. Day/night palettes and archives are local build artifacts and
are ignored by git. The legacy
`telegram/gruvbox-material-dark-medium.tdesktop-theme` output remains a night
alias for compatibility with the older manual workflow.

For the live setup, the desktop profile runs
`telegram/generate-theme.py --runtime auto`, which writes one stable file at
`$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme`. Import that file in
Telegram and press **Apply Theme** once. Telegram Desktop watches the native path
of a loaded local theme and reapplies it when the file changes, so
`darkman/scripts/telegram` can switch the contents between day and night on each
solar transition without editing `tdata` or automating UI clicks. See
[telegram](telegram.md) for the palette and bootstrap decision.

The wallpaper is PNG, not JPEG: an earlier JPEG source got silently bit-corrupted
somewhere in git history (mid-stream, not just a truncated tail — every JPEG
blob across that history failed independent decode with `djpeg`/`jpegtran`/
ImageMagick, each erroring at the same offset). The generator's own validation
only checked for a JPEG start-of-image marker, so the corruption shipped for
several commits and silently failed to apply in Telegram, which uses a strict
decoder. PNG's checksummed chunks make that class of silent corruption far less
likely to reoccur unnoticed.

The artwork itself is inset on a taller dark canvas so Telegram's cover-style
wallpaper scaling crops and zooms it less in a narrow chat pane.

Regardless of source format, verify a new wallpaper source decodes with a real
decoder (`python3 -c "from PIL import Image; Image.open(...).load()"` or
`magick identify`) before committing it — `generate-theme.py` only checks the
container's magic bytes, not that the pixel data is intact.

The alternate procedural wallpaper is intentionally retained as a backup. Each
Telegram generation writes it to `telegram/background-backup.png`; that file is
also a local build artifact. The implementation stays in
`telegram/generate-theme.py`, so the backup is reproducible from `colors.toml`
without storing a second large binary in git.

Telegram-specific semantic overrides live in `telegram/generate-theme.py` when
a palette surface has no useful cross-application equivalent. The vertical chat
folder sidebar uses Telegram's `sideBar*` keys explicitly and inherits whichever
Telegram variant is active rather than leaking Telegram's built-in blue defaults.

Voice messages also have Telegram-specific overrides. The idle waveform is kept
neutral rather than being used as an unread/read signal. Telegram's theme API
does not expose separate colors for an unread idle voice message and a
listened-but-stopped one: unread media is represented by the small dot after the
duration. That dot shares `msgFileInBg` with the incoming play button, so the
theme gives both the active variant's yellow accent. Exact whole-message
unread/read recoloring would require patching Telegram Desktop itself.

Do not hand-edit generated Telegram day/night palette files. The source is the
shared renderer plus Telegram's variant transformation in
`telegram/generate-theme.py`. Other generated configs consume shared palette
surfaces rather than maintaining independent values. Yazi's existing
classic-Gruvbox accents are intentionally preserved as compatibility entries in
`colors.toml`; regeneration therefore does not restyle Yazi. Its vendored
`tmtheme.xml` is syntax-highlighting metadata from the upstream flavor and is
not used as the desktop palette source.

The Claude Code theme deliberately leaves `claudeShimmer` at its built-in color;
overriding it made the thinking animation harder to distinguish.

## Helium

Helium is intentionally not themed through GTK or Chromium's autogenerated/User
Color theme. GTK gives poor vertical-tab contrast, while User Color goes through
the Material color generator and cannot preserve all exact Gruvbox surfaces.

`helium/apply-gruvbox-theme.py` generates an unpacked Chromium theme at
`$XDG_DATA_HOME/dotfiles/helium-gruvbox/manifest.json` directly from
`colors.toml`. The palette mapping is intentionally the same as the very first
Helium Gruvbox theme added to this repo:

- main frame / toolbar / vertical tab strip / omnibox / NTP background:
  `bg (#282828)`;
- "+ New Tab" control: `bg (#282828)`, i.e. deliberately equal to the strip;
- inactive frame / buttons: `bg_alt (#32302f)`;
- NTP header: `bg_soft (#3c3836)`;
- text: `fg (#d4be98)`;
- links: `blue (#7daea3)`.

### Which theme key paints which vertical-tab surface

This is easy to get wrong and expensive to guess at, so it was measured off
pixels in a running Helium rather than reasoned from key names. With
`frame=#282828`, `toolbar=#504945`, `background_tab=#282828` loaded, a screenshot
of the strip gives:

| surface                | measured  |
| ---------------------- | --------- |
| empty strip background | `#3c3836` |
| inactive tab row       | `#3c3836` |
| active tab row         | `#3c3836` |
| "+ New Tab" control    | `#282828` |

`#3c3836` is exactly `mix(toolbar, frame, 50%)`. So, for the vertical tab strip:

- the strip background is **`mix(toolbar, frame, 50%)`**;
- the **active tab has no color of its own** — it renders as exactly that strip
  background, so it can never be separated from it via the theme;
- **inactive tabs** likewise render as the strip background;
- **`background_tab` paints only the "+ New Tab" control**;
- `omnibox_background` plays no part in the tab strip at all.

**A lighter active-tab "pill" is therefore not achievable through an extension
theme.** Raising `toolbar` to try to lighten the active tab only lightens the
whole strip (and the toolbar row) with the tab still merged into it. This is the
Chromium behavior a custom theme opts into: the Material tab-state treatment that
draws a distinct selected-tab surface applies to Helium's _native_ colors, and
loading a custom theme flattens it. Getting the pill back means either dropping
this custom theme (and accepting non-exact Gruvbox surfaces from Helium's
Material generator) or patching the C++ mixer — which is what the abandoned
`helium/gruvbox-exact-tabs.patch` did.

Note also that the comment inside that patch claims Helium wires the active tab
to the location-bar surface and "+ New Tab" to `toolbar`. The measurements above
contradict it. **Do not re-litigate this mapping from color-key names, from that
patch, or from Chromium source — re-measure.**

Contrast is also less available than it looks: `bg_alt (#32302f)` and
`bg_soft (#3c3836)` are close enough to `bg (#282828)` that at that delta only
the full-strength `tab_text` vs `tab_background_text` difference registers, which
reads as "the active tab only highlights its text".

Note that `toolbar` also paints the main toolbar row, so it cannot be raised for
the tab strip alone without also lightening that row.

There is one important update gotcha. Chromium's `ThemeService` skips reapplying
an already-current unpacked theme when it is loaded again with the same extension
ID and is not seen as an update. The original manual setup avoided this by using
**Reload** in the extensions page after edits. A generated manifest with a fixed
`version = 1.0.0` can therefore leave an older compiled theme pack active even
though the manifest on disk has changed.

The helper manages this automatically: whenever the generated `theme` payload
changes it bumps the unpacked extension version; an unchanged payload keeps the
same version. On the next complete Helium restart this makes the changed theme an
extension update and causes `ThemeService` to rebuild/reapply the theme pack. The
version is runtime metadata only; Gruvbox values still come exclusively from
`colors.toml`.

No custom Helium/Chromium source build is part of the theming setup. Do not add a
browser fork or native color patch unless the extension-theme approach has first
been visually disproved — as it has been for the active-tab pill specifically
(see above); the abandoned `helium/gruvbox-exact-tabs.patch` is what that would
look like if it becomes worth doing.

On Arch, `helium-browser-bin` reads `$XDG_CONFIG_HOME/helium-browser-flags.conf`.
Its launcher deliberately does not expand `~` or `$HOME`, so the theme helper
writes a managed `--load-extension=<absolute path>` block while preserving valid
unrelated loaded extensions. It removes stale/relative/nonexistent extension
entries such as `.` before writing the managed block; otherwise Chromium
resolves them from its launch directory and shows a misleading "Manifest file is
missing or unreadable" dialog. The generated theme directory is validated for a
readable `manifest.json` before the flags file is changed. `dots apply` runs the
helper automatically; restart Helium completely after applying changes.

### The wrapper's tilde bug (why the path is written `/home/./<user>/...`)

`/opt/helium-browser-bin/helium-wrapper` sanitizes each flags line with

```sh
safe_line=${safe_line//~/\\~}
```

intending to stop `~` from expanding. In Bash the _pattern_ half of
`${var//pattern/repl}` is itself tilde-expanded, so the pattern is really
`$HOME`: the line rewrites any absolute path under the home directory back into
a literal `~` path, which then never expands. Helium is launched with
`--load-extension=~/.local/share/dotfiles/helium-gruvbox`, that directory does
not exist, the theme extension fails to load, and Chromium eventually drops the
theme altogether — `extensions.theme` in `Preferences` resets to
`{"id": "", "system_theme": 1}` and the browser silently falls back to its
native colors. This is **not** cosmetic, and it makes theming changes look like
they intermittently "do nothing".

`wrapper_safe_path()` in the helper therefore writes the directory as
`/home/./<user>/.local/share/dotfiles/helium-gruvbox`. That resolves identically
for the kernel and Chromium but no longer contains the literal `$HOME`
substring, so the wrapper's replacement does not match it.

To verify a theme actually loaded, check that
`$XDG_DATA_HOME/dotfiles/helium-gruvbox/Cached Theme.pak` has an mtime _newer_
than `manifest.json` after a restart. Chromium rebuilds that pack when it picks
up a new manifest version; a pack older than the manifest means the theme did
not load. Do not rely on the browser merely looking themed — the previously
compiled pack can survive in the profile.

## Light/dark

Darkman's solar state becomes `dark` or `light`. Most application surfaces stay
pinned to Gruvbox dark in both states. There are now two intentional visual
exceptions: the Hyprland wallpaper and Telegram Desktop.

The GTK hook still always sets `color-scheme=prefer-dark` and selects the first
installed theme from:

1. `Gruvbox-Material-Dark`
2. `Gruvbox-Dark-Medium`
3. `Gruvbox-Dark`

If none exists it falls back to `Adwaita-dark` and prints a warning. Hooks live
in the XDG data dir (`~/.local/share/darkman` via `dots apply`), not
`~/.config`. GTK4/libadwaita is not fully controlled by `gtk-theme`, but the
system color-scheme remains dark. Telegram does not depend on this system value;
it switches through its watched local theme file instead.

`hypr/hyprsunset.conf` is independent screen gamma/temperature control and does
not switch application themes.

### Wallpaper and Telegram switch with the solar state

`darkman/scripts/wallpaper` swaps the Hyprland wallpaper between
`hypr/wallpapers/light.png` and `hypr/wallpapers/dark.png` on every darkman
transition, over `hyprpaper`'s IPC (`hyprctl hyprpaper wallpaper`) — not
through a `hyprpaper.conf`, which this build ignores. See
[hypr](hypr.md#wallpaper-hyprpaper-driven-entirely-over-ipc) for the mechanism
and the config-file gotcha; `hypr/modules/autostart.lua` also resyncs it to
the current `darkman get` state on every Hyprland start, since restarting only
`hyprpaper` doesn't make `darkman.service` refire its hooks.

`darkman/scripts/telegram` maps `light` to the full olive/taupe Telegram day
variant and `dark` to the Gruvbox night variant. It rewrites
`$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme`; Telegram's own file
watcher reloads the active custom theme from that stable path. `dots apply`
creates/resyncs that runtime file through the desktop profile generator, but the
first Telegram import still requires one manual **Apply Theme** confirmation.

### Fixing a stale `~/.local/share/darkman` on an existing machine

`darkman/scripts` is meant to be symlinked wholesale to `$XDG_DATA_HOME/darkman`
(`DOTS_MANAGED_LINKS` in `scripts/dots-lib.sh`) — darkman scans that directory's
entries directly as hook scripts (not a further `scripts/` subdirectory; see
`darkman(1)`). A machine set up before this mapping existed can have a real
`~/.local/share/darkman` directory instead (containing unmanaged scripts),
which makes every hook — including the always-dark GTK one — silently fail to
run (`fork/exec ...: no such file or directory` for the directory-shaped entry,
and the unmanaged scripts run instead). `dots doctor` reports this as
`$XDG_DATA_HOME/darkman does not point to .../darkman/scripts`; `dots migrate`
now backs up and removes the stale directory (preserving any unmanaged scripts
in the backup under `$XDG_STATE_HOME/dotfiles/backups/`) so a subsequent
`dots apply` can create the correct symlink. `dots apply` cannot fix this by
itself in one pass: it runs `install_links` (which refuses to clobber a real,
non-symlink directory) before `dots migrate` — run `dots migrate` first on an
affected machine.
