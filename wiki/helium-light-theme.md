---
title: helium standalone themes
type: topic
updated: 2026-08-31
covers:
  - helium/gruvbox-light/manifest.json
  - helium/gruvbox-dark/manifest.json
---

# Helium Gruvbox Light/Dark — standalone experiment

`helium/gruvbox-light/manifest.json` and `helium/gruvbox-dark/manifest.json` are
standalone unpacked Chromium themes built from the repository's Gruvbox Material
light and dark palettes.

They are deliberately **not** part of `dots apply`, `scripts/generate-theme.py`,
darkman, or `helium/apply-gruvbox-theme.py`. The normal managed Helium state
continues to use Chromium's native User Color theme with `color_scheme=system`,
which is the supported live light/dark path.

The exact standalone variants are static Chromium theme extensions. Chromium's
theme manifest supports `colors`, `images`, `properties`, and `tints`, but no
system-dependent light/dark variants inside one theme. Therefore loading one of
these exact manifests replaces the adaptive theme until that unpacked theme is
disabled again.

Light mapping:

- sidebar/inactive tabs: `#f2efe8` (`bg_hard`);
- toolbar/active surface: `#ece9e2` (`bg_soft`);
- omnibox/page background: `#fbfaf7` (`bg`);
- primary text: `#3c3836` (`fg`);
- links/accent: `#45707a` (`blue`).

Dark mapping:

- sidebar/inactive tabs: `#1d2021` (`bg_hard`);
- toolbar/active surface: `#3c3836` (`bg_soft`);
- omnibox/page background: `#282828` (`bg`);
- primary text: `#d4be98` (`fg`);
- links/accent: `#7daea3` (`blue`).

To inspect either exact variant without changing dotfiles automation, check out
the branch and use Helium's Extensions page with Developer mode -> Load unpacked,
selecting either `helium/gruvbox-light/` or `helium/gruvbox-dark/`.

For the actual desktop behavior, leave both standalone themes disabled. Then the
managed native Helium theme follows darkman's XDG appearance signal live:
`dots theme light`, `dots theme dark`, sunrise, and sunset all switch the browser
without loading a different extension or restarting it.
