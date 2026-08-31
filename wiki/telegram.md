---
title: telegram
type: component
updated: 2026-08-31
covers:
  - telegram/
---

# telegram — Gruvbox theme decisions

Telegram keeps Gruvbox accents and the shared palette as its base, but chat-body readability takes priority over exact palette matching. In bright ambient light the normal `#d4be98` text on near-black Gruvbox bubbles felt muddy even when the numerical contrast ratio was acceptable.

The chat surface therefore uses a Telegram-only muted olive/taupe treatment inspired by dim Telegram themes rather than pushing the bubbles further toward black. Incoming bubbles use `#41423b`, outgoing bubbles `#5b5c52`, body text `#f3f0e6`, and small metadata `#d8d4c8`. Selected and service/system surfaces use nearby olive shades and are kept nearly opaque so the wallpaper does not reduce legibility.

Keep these values in `telegram/generate-theme.py`, not `colors.toml`: they solve a Telegram-specific daylight readability problem and should not brighten or recolor Kitty, Neovim, Quickshell, or the rest of the desktop. The generated `telegram/colors.tdesktop-theme` must stay in sync with the generator.
