---
title: scripts-scratch
type: component
updated: 2026-09-02
covers:
  - quickshell/components/ScratchOverlay.qml
  - quickshell/dots-shell
  - quickshell/picker-helper.py
  - scripts/nvim-scratch-toggle.sh
  - scripts/nvim-scratch-run.sh
  - scripts/nvim-scratch-quit.sh
---

# Scratch note — self-pasting nvim panel

`SUPER+N` launches the nvim QAT through `nvim-scratch-toggle.sh`. The native
Quickshell `components/ScratchOverlay.qml` remains available through the manual
`dots-shell scratch` command, but it does not own the hotkey.

## Optional Quickshell behavior

`dots-shell scratch` records the currently focused Hyprland window address
before opening the overlay and passes it to the Quickshell `scratch` IPC target.
The editor is keyboard-focused immediately.

- `Esc` hides the overlay without losing the current draft;
- pressing `Super+N` again toggles the same draft back open;
- `Ctrl+Enter` copies the note to the Wayland clipboard, closes the overlay,
  refocuses the window that was active when scratch opened, and pastes there;
- after a successful paste request the in-memory draft is cleared.

The paste helper lives in `quickshell/picker-helper.py`. It waits briefly after
the exclusive layer-shell surface closes, focuses the recorded Hyprland address,
then uses `wtype`. Kitty targets receive `Ctrl+Shift+V`; other applications
receive normal `Ctrl+V`. This preserves the behavior of the proven old scratch
implementation without the QAT process/cgroup machinery.

If the recorded target no longer exists, the text has still been placed on the
clipboard; the focus/paste step simply cannot target that vanished window.

## Why the active nvim implementation is complicated

The nvim scripts account for two QAT gotchas:

1. A Kitty quick-access panel is an exclusive layer-shell surface, so synthetic
   `wtype` input sent before the panel disappears is consumed by the panel.
2. Kitty panel children live in a transient systemd scope. A plain `setsid`
   helper is still inside that cgroup and is killed when the panel exits; the old
   `nvim-scratch-quit.sh` therefore had to launch its paste helper via
   `systemd-run --user --collect`.

Those constraints disappear from the optional Quickshell implementation because
the long-running shell owns the overlay itself and can dispatch paste only after
making the surface invisible.

The active files keep their former roles: `nvim-scratch-toggle.sh` launches the
QAT/editor, `nvim-scratch-run.sh` autosaves the fixed scratch file even through
`:q!`, and `nvim-scratch-quit.sh` performs the detached focus/paste sequence and
kills the panel. `hypr/modules/binds.lua` invokes the toggle script directly.
