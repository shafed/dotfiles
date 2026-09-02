---
title: scripts-scratch
type: component
updated: 2026-09-02
covers:
  - kitty/quick-access-terminal-scratch.conf
  - quickshell/components/ScratchOverlay.qml
  - quickshell/dots-shell
  - quickshell/picker-helper.py
  - scripts/nvim-scratch-toggle.sh
  - scripts/nvim-scratch-run.sh
  - scripts/nvim-scratch-quit.sh
  - hypr/modules/rules.lua
---

# Scratch note — fullscreen nvim clipboard panel

`SUPER+N` launches the active nvim QAT through `nvim-scratch-toggle.sh`. The
dedicated `kitty/quick-access-terminal-scratch.conf` uses `edge center`, so the
panel covers the whole display. Its background is fully opaque; there is no
scratch-specific Hyprland blur or dim rule.

Re-triggering `Super+N` hides/shows the same QAT instance, so the draft survives
a temporary hide. `nvim-scratch-run.sh` starts nvim in insert mode and writes the
fixed `~/.cache/nvim-scratch.md` on `VimLeavePre`, including exits through the
fast `:q!` mappings.

When nvim exits, `nvim-scratch-quit.sh` copies the note to the Wayland clipboard
with `wl-copy`, clears the scratch file, and closes the panel. It deliberately
**does not synthesize a paste or send keys to the previously focused window**;
the user decides when and where to paste the clipboard contents.

CopyQ has no special integration with the nvim QAT. `Super+V` simply toggles
CopyQ through `dots-shell clipboard`; the scratch panel is not automatically
hidden or modified for it.

## Optional Quickshell behavior

The native Quickshell `components/ScratchOverlay.qml` remains available through
the manual `dots-shell scratch` command, but it does not own the hotkey.

`dots-shell scratch` records the currently focused Hyprland window address
before opening the overlay and passes it to the Quickshell `scratch` IPC target.
The editor is keyboard-focused immediately.

- `Esc` hides the overlay without losing the current draft;
- reopening the manual scratch route restores the same draft;
- `Ctrl+Enter` copies the note to the Wayland clipboard, closes the overlay,
  refocuses the window that was active when scratch opened, and pastes there;
- after a successful paste request the in-memory draft is cleared.

The optional Quickshell paste helper lives in `quickshell/picker-helper.py`. It
waits briefly after the exclusive layer-shell surface closes, focuses the
recorded Hyprland address, then uses `wtype`. Kitty targets receive
`Ctrl+Shift+V`; other applications receive normal `Ctrl+V`.
