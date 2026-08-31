---
title: telegram
type: component
updated: 2026-08-31
covers:
  - telegram/
---

# telegram — Gruvbox theme decisions

Telegram keeps the shared Gruvbox Material Dark Medium palette, but message-body readability takes priority over matching the shared `fg` surface exactly. In bright ambient light the normal `#d4be98` text against the medium-dark message bubbles loses too much perceived contrast, even though it is comfortable indoors.

For chat bubbles, use `fg_bright` for the body text, `bg_hard` for incoming messages, and keep `bg_soft` for outgoing messages. This preserves the visual distinction between incoming and outgoing bubbles while raising contrast without introducing colors outside the shared Gruvbox palette. Message timestamps use `fg_soft` rather than gray because their small size makes the dimmer gray especially hard to read during the day.

Do not raise the contrast of the entire desktop palette to solve this. The problem is specific to Telegram's dense chat surface; changing `colors.toml` would make unrelated applications unnecessarily bright.
