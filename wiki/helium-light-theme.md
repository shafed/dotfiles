---
title: helium light theme
type: topic
updated: 2026-08-31
covers:
  - helium/gruvbox-light/manifest.json
---

# Helium Gruvbox Light — standalone experiment

`helium/gruvbox-light/manifest.json` is a standalone unpacked Chromium theme built
from the repository's `[colors_light]` Gruvbox Material palette.

It is deliberately **not** part of `dots apply`, `scripts/generate-theme.py`,
darkman, or `helium/apply-gruvbox-theme.py`. The normal managed Helium state
continues to use Chromium's adaptive native User Color theme.

The standalone theme exists only for visual/manual testing of exact light
Gruvbox surfaces. Its main mapping is:

- sidebar/inactive tabs: `#f2efe8` (`bg_hard`);
- toolbar/active surface: `#ece9e2` (`bg_soft`);
- omnibox/page background: `#fbfaf7` (`bg`);
- primary text: `#3c3836` (`fg`);
- links/accent: `#45707a` (`blue`).

To try it without changing dotfiles automation, check out the branch and use
Helium's Extensions page with Developer mode -> Load unpacked, selecting
`helium/gruvbox-light/`.

Removing/turning off the unpacked theme returns control to the currently managed
Helium theme. Do not add this directory to Helium launch flags unless the
standalone experiment is intentionally promoted into managed state later.
