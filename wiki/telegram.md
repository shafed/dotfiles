---
title: telegram
type: component
updated: 2026-08-31
covers:
  - telegram/
  - darkman/scripts/telegram
  - profiles/desktop.toml
---

# telegram — day/night theme decisions

Telegram is the deliberate exception to the desktop's otherwise dark-only application palette. Bright ambient light made the original near-black Gruvbox Telegram surface feel muddy even when the numerical contrast ratio was acceptable, so the `light` solar state uses a Telegram-only muted olive/taupe palette inspired by the warm landscape wallpaper rather than a conventional white theme.

The daylight treatment is applied to the whole Telegram palette, not only message bubbles. Its core surfaces are `#34352f` / `#41423b` / `#4b4c44` / `#55564d`, main text is `#f3f0e6`, strong text is `#fffaf0`, and small metadata is `#d8d4c8`. Incoming bubbles use `#41423b`, outgoing bubbles `#5b5c52`; warm yellow/orange and muted aqua/green accents keep the Gruvbox relationship without changing `colors.toml`. The `dark` solar state remains the high-contrast Gruvbox Material Dark Medium Telegram palette.

`telegram/generate-theme.py` renders both variants from the same base renderer. Normal generation writes local day/night palettes and archives; those outputs are build artifacts and are not tracked. `--runtime light|dark` instead writes one stable file at `$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme`.

The stable runtime path is intentional. Telegram Desktop watches the local theme file from which the active custom theme was loaded and reapplies it when that file changes. `darkman/scripts/telegram` therefore only updates this one file on a solar transition; it does not edit Telegram's `tdata`, click UI controls, or depend on Telegram's system-theme setting. The desktop profile generator creates the runtime file during `dots apply` using the current `darkman get` state.

There is one unavoidable bootstrap step: import `$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme` in Telegram and press **Apply Theme** once. After Telegram has that stable path as its custom theme, `darkman` transitions update it automatically while Telegram is running.

Keep the daylight values in `telegram/generate-theme.py`, not `colors.toml`: they solve a Telegram-specific readability problem and should not recolor Kitty, Neovim, Quickshell, or other applications.
