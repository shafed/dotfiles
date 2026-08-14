---
title: scripts-scratch
type: component
updated: 2026-08-14
covers:
  - scripts/nvim-scratch-toggle.sh
  - scripts/nvim-scratch-run.sh
  - scripts/nvim-scratch-quit.sh
---

# scripts — scratch note that pastes itself

Parent: [scripts](scripts.md). Built on the QAT panel mechanism described in
[scripts-pickers](scripts-pickers.md).

## nvim-scratch-toggle.sh / nvim-scratch-run.sh / nvim-scratch-quit.sh — scratch note that pastes itself

`SUPER, N` (hypr/hyprland.lua) toggles a floating kitty+nvim scratchpad for
jotting a quick note and pasting it into whatever text box was focused before
the scratchpad opened — no manual copy/paste. Reuses the QAT mechanism above
(`launch_qat`/`lib.sh`) rather than a Hyprland special workspace, so it gets
the same "re-press to toggle visibility, process survives a hide" behavior as
apps.sh/bookmarks.sh for free, in its own `scratch` instance-group.

- `nvim-scratch-toggle.sh`: records the currently-focused window's Hyprland
  address (`hyprctl activewindow`) to `~/.cache/nvim-scratch-target` — this
  is what quit will paste back into — then calls `launch_qat "scratch"` with
  `/usr/bin/env bash nvim-scratch-run.sh <scratch_file> <quit_script>` (fixed
  scratch-file path, so content survives a hide/reshow cycle). The address
  capture happens unconditionally on every press: harmless when the press is
  about to *hide* the panel (nothing reads it until nvim actually quits,
  which can't happen while hidden), correct when the press is about to
  *show* it.
- `nvim-scratch-run.sh`: `nvim +startinsert
  "+autocmd VimLeavePre * silent! write" -- "$1"` (drop straight into
  insert mode — this is a "jot something down" scratchpad, not editing)
  then `exec "$2"` (the quit script). The VimLeavePre autosave is
  load-bearing: the user's fast-quit maps (`<M-q>`/`<M-Esc>`, all modes
  including insert — `nvim/lua/config/keymaps.lua`) run `:q!`, which
  discards the buffer, and the quit hook would then find an empty scratch
  file and paste nothing. For this scratchpad every exit means "I'm done,
  paste it".
- `nvim-scratch-quit.sh`: runs once nvim exits (inherits its PID via `exec`
  in run.sh). `wl-copy`s the scratch file — through `printf '%s'
  "$(<file)"`, which strips all trailing newlines (nvim always writes a
  final one; it would land as an extra Enter in the target text box) —
  clears it for next time, then
  spawns a paste helper via **`systemd-run --user`** and kills the panel;
  the helper waits for the panel process to die, runs
  `hyprctl dispatch 'hl.dsp.focus({ window = "address:..." })'` to refocus the
  recorded address, and simulates a paste via
  wtype — no ydotool/ydotoold on this machine, and wtype needs no daemon on
  wlroots compositors. The chord depends on the target's Hyprland class:
  plain `ctrl+v` everywhere except a `kitty` target, which gets
  `ctrl+shift+v` (kitty's own `kitty_mod+v` paste binding — plain ctrl+v
  isn't bound to anything in a terminal).

⚠️ Gotcha (paste MUST happen after the panel dies, from a process outside
the panel's cgroup) — two layers, both hit in sequence:

1. The panel is a layer-shell overlay with `--focus-policy=exclusive` —
   while it is alive it swallows ALL keyboard input, **including wtype's
   synthetic keys**. The first cut focused the target and pasted before
   killing the panel (via an EXIT trap): the log showed `focuswindow`
   dispatched and wtype exiting 0, yet nothing arrived — the chord went
   into the still-open panel. Diagnosed by elimination with a disposable
   `kitty --class wtype-probe -e sh` target plus `kitty @ get-text` to
   inspect the pty directly: the identical wtype chord pastes fine when no
   panel is involved. And the kill can't simply be moved earlier in the
   same script: the panel closing HUPs its pty, which would take the script
   down with it mid-paste — the paste has to come from a detached helper
   that outlives the panel.
2. A `setsid`-detached helper is NOT detached enough: kitty spawns the
   panel's children inside a transient systemd scope (`kitty-<pid>-N.scope`
   — visible in the journal as "Started kitty child process ..."), and when
   the panel dies systemd tears down the whole scope **cgroup**. `setsid`
   changes the session (immune to the pty HUP) but not the cgroup, so the
   helper was reaped before writing a single log line. `systemd-run --user
   --collect` puts the helper in its own scope outside the doomed cgroup
   (with `WAYLAND_DISPLAY`/`HYPRLAND_INSTANCE_SIGNATURE` passed through via
   `--setenv`, since the transient unit doesn't inherit the caller's env
   beyond what the user manager already has). The helper then polls
   `kill -0` until the panel PID is gone, polls `hyprctl activewindow`
   until the target address is actually focused, and only then types the
   chord.

⚠️ Gotcha (why run.sh is a real file, not an inline string): the first cut
passed `/usr/bin/env bash -c "nvim -- '$scratch_file'; exec '$quit_script'"`
straight to `launch_qat`. That string has to survive being re-serialized
across the remote-control call into the already-running main kitty and the
quick-access-terminal kitten's own re-exec of `+kitten panel` before it
becomes argv for the panel's child process — it did not survive intact: nvim
came up with zero arguments (landing on its startup dashboard instead of the
scratch file), consistent with the semicolon-joined, quote-embedded string
being re-tokenized somewhere along that chain rather than passed through
as one opaque token. A plain script path plus two plain argv tokens (no
shell metacharacters left to mangle) fixed it — same shape as apps.sh's
`bash "$script_path" "${pick_args[@]}"`, which never hit this because it
never embeds `;`/quotes in what it hands to `launch_qat`.

⚠️ Gotcha (this is why quit_script kills its own parent): kitty.conf leaves
`close_on_child_death` at its default (`no`, see the QAT gotcha above) — the
panel does NOT disappear on its own once the wrapped command exits, it would
sit there showing a dead pane. Since `nvim-scratch-quit.sh` is `exec`'d in
place of run.sh, `$PPID` inside it is the panel's own kitty process; quit.sh
kills that PID explicitly on every exit path so the panel actually closes
instead of lingering.
