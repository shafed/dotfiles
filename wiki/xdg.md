---
title: xdg
type: topic
updated: 2026-09-01
covers:
  - xdg/mimeapps.list
---

# XDG — default application associations

`xdg/mimeapps.list` is the single source of truth for default application
associations on all machines. It is deployed as a symlink to
`~/.config/mimeapps.list` by the base profile.

## Image viewer

`imv` is the default image viewer. It handles PNG, JPEG, GIF, WebP, BMP, SVG,
TIFF, and other common image formats.

## PDF viewer

`sioyek` is the default PDF viewer, wrapped through `~/.local/bin/sioyek` to
set the correct environment variables.

## Browser

`helium-browser` is the default browser for HTTP/HTTPS links. Firefox is used
as a fallback for some HTML file types.

## Editor

`nvim-open.desktop` is the default for text files and source code. This
desktop file opens files in Neovim with the proper configuration.
