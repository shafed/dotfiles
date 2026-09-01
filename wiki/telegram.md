---
title: telegram
type: component
updated: 2026-09-01
covers:
  - telegram/
  - darkman/scripts/telegram
  - scripts/dots-telegram-generator.sh
  - profiles/desktop.toml
---

# telegram — day/night theme decisions

Telegram is the deliberate exception to the desktop's otherwise dark-only application palette. Bright ambient light made the original near-black Gruvbox Telegram surface feel muddy even when the numerical contrast ratio was acceptable, so the `light` solar state uses a Telegram-only muted olive/taupe palette inspired by the warm landscape wallpaper rather than a conventional white theme.

The daylight treatment is applied to the whole Telegram palette, not only message bubbles. Its core surfaces are `#34352f` / `#41423b` / `#4b4c44` / `#55564d`, main text is `#f3f0e6`, strong text is `#fffaf0`, and small metadata is `#d8d4c8`. The compose field deliberately uses the strong foreground so newly typed text matches the rest of the bright UI instead of retaining the warmer main-text color. Incoming bubbles use `#41423b`, outgoing bubbles `#5b5c52`; warm yellow/orange and muted aqua/green accents keep the Gruvbox relationship without changing `colors.toml`.

The `dark` solar state deliberately keeps the original Gruvbox Material Dark Medium Telegram treatment instead of inheriting daylight contrast tweaks. Normal message text uses the warm shared foreground `#d4be98`, incoming bubbles use `#32302f`, and message metadata returns to the dimmer Gruvbox gray. Selected states can still use the brighter Gruvbox foreground. Daylight-only readability changes must remain variant-local so the night palette never drifts toward white text again.

`telegram/generate-theme.py` renders both variants from the same base renderer. Normal generation writes local day/night palettes and archives; those outputs are build artifacts and are not tracked. The live target is one stable file at `$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme`.

The Telegram wallpaper has one direct source of truth: `telegram/background.png`. The generator does not create, recolor, decode, or keep backup wallpapers; it embeds that PNG verbatim into both day and night theme archives. To change the chat background, replace that file with another PNG and run `./dots apply` or switch the theme with `./dots theme light` / `./dots theme dark`. The next generated runtime theme contains the new image.

The stable runtime path and its inode are both intentional. Telegram Desktop uses `QFileSystemWatcher` on the local theme file and reapplies it when that watched file changes. Replacing the path atomically with a new inode drops that watch, so a first switch can work while the next one is ignored. `scripts/dots-telegram-generator.sh` therefore builds the requested variant in a temporary location and rewrites the existing runtime file in place. Both `darkman/scripts/telegram` and the desktop profile generator use that wrapper; neither edits Telegram's `tdata` or clicks UI controls.

There is one unavoidable bootstrap step: import `$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme` in Telegram and press **Apply Theme** once. If an older implementation already replaced that file atomically, its watcher is already lost; after updating to the inode-preserving implementation, import the runtime file once more. Future `light` / `dark` transitions then reuse the watched inode.

Keep the daylight values in `telegram/generate-theme.py`, not `colors.toml`: they solve a Telegram-specific readability problem and should not recolor Kitty, Neovim, Quickshell, or other applications.
