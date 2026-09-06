---
title: scripts-scratch
type: component
updated: 2026-09-06
covers:
  - kitty/quick-access-terminal-scratch.conf
  - kitty/quick-access-terminal-textarea.conf
  - quickshell/components/ScratchOverlay.qml
  - quickshell/dots-shell
  - quickshell/picker-helper.py
  - scripts/nvim-scratch-toggle.sh
  - scripts/nvim-scratch-run.sh
  - scripts/nvim-scratch-quit.sh
  - scripts/nvim-textarea.sh
  - hypr/modules/binds.lua
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

## External GUI textarea (`Super+Shift+E`)

`scripts/nvim-textarea.sh` turns the currently focused GUI text field into a
compact temporary Neovim editor. Unlike the fullscreen scratch note, textarea
mode has its own `kitty/quick-access-terminal-textarea.conf`: a 90-column,
12-line `center-sized` layer-shell panel. It is launched directly with
`kitten quick-access-terminal`, not through the main kitty OS window. This is
important because the main kitty window is pinned to workspace 1; the textarea
panel therefore appears over the current display without switching workspaces.

The launcher records the focused Hyprland window address and the current
`kanata` layout, then waits briefly for the `Super+Shift+E` modifiers to be
released before sending `Ctrl+A` and `Ctrl+C` as separate `wtype` operations.
Before copying it seeds the Wayland clipboard with a unique sentinel and polls
for that value to change for up to about half a second. This makes Telegram's
asynchronous clipboard handoff reliable while still distinguishing a genuinely
empty field from a failed/late copy. The captured plain text is written to
`~/.cache/nvim-textarea/text.txt` and opened in the normal Neovim config in
insert mode with the cursor at the end.

Re-triggering `Super+Shift+E` while the editor process exists only hides/shows
that same QAT. The launcher checks an editor PID before capture, so a re-trigger
cannot accidentally replace the draft with text copied from the panel itself.

Every Neovim exit is treated as apply, including the fast mappings that execute
`:q!`: a `VimLeavePre` autocmd writes the temporary buffer first. On exit the
script:

- copies the edited text to the Wayland clipboard;
- hides the exclusive-focus textarea QAT before trying to refocus the source;
- focuses the exact Hyprland address recorded at launch;
- sends `Ctrl+A` and pastes the result (or `BackSpace` for an empty result);
- restores the `kanata` layout that was active before the editor opened;
- clears the temporary text after a successful replacement and terminates the
  textarea QAT.

If the original window disappeared, nothing is pasted: the edited text remains
both in the clipboard and in `~/.cache/nvim-textarea/text.txt` for recovery.
Kitty is rejected as a source window because `Ctrl+A` has terminal semantics
there rather than selecting a GUI field. The bridge is intentionally plain-text
only; rich formatting copied from Telegram/browser inputs is not preserved.

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
