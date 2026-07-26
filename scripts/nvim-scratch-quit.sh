#!/usr/bin/env bash
# Runs after nvim exits inside the QAT scratch panel (see
# nvim-scratch-toggle.sh): copies the scratch note to the clipboard, then
# closes the panel and — from a helper detached into its own systemd user
# scope — focuses back whatever window had focus before the scratchpad
# opened and simulates a paste into it via wtype. Clears the scratch file so
# the next SUPER+N starts blank.
#
# Why the paste helper runs under `systemd-run --user`:
# - The panel is a layer-shell overlay with --focus-policy=exclusive: while
#   it is alive it swallows ALL keyboard input, including wtype's synthetic
#   keys — so the paste can only happen AFTER the panel dies.
# - kitty spawns the panel's child processes inside a transient systemd
#   scope (kitty-<pid>-N.scope). When the panel dies, systemd tears down
#   that scope's whole cgroup — a plain `setsid` helper does NOT survive
#   (setsid changes the session, not the cgroup; this was tried and the
#   helper was reaped before it could do anything). `systemd-run --user`
#   puts the helper in its own scope, outside the doomed cgroup.
# - kitty.conf leaves close_on_child_death=no (see wiki/scripts.md), so the
#   panel does not close on its own when this script exits — we must kill
#   $PPID (we are exec'd in place of run.sh's shell, so $PPID is the
#   panel's own kitty process).

set -euo pipefail

scratch_file="$HOME/.cache/nvim-scratch.md"
state_file="$HOME/.cache/nvim-scratch-target"
log_file="/tmp/nvim-scratch-quit.log"
panel_pid="$PPID"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file"; }

if [[ ! -s "$scratch_file" ]]; then
  log "empty scratch file, nothing to paste"
  kill "$panel_pid" 2>/dev/null || true
  exit 0
fi

# $(<file) strips ALL trailing newlines (nvim always writes a final one,
# and stray blank lines at the end shouldn't become extra Enters in the
# target text box).
printf '%s' "$(<"$scratch_file")" | wl-copy
log "copied scratch file to clipboard"
: >"$scratch_file"

target="$(cat "$state_file" 2>/dev/null || true)"

if [[ -n "$target" ]]; then
  systemd-run --user --collect --quiet \
    --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
    --setenv=HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
    bash -c '
      target="$1"; panel_pid="$2"; log_file="$3"
      log() { printf "[%s] %s\n" "$(date "+%F %T")" "$*" >>"$log_file"; }
      log "paste helper started (target=$target panel_pid=$panel_pid)"

      # Wait for the panel process to be really gone (its exclusive
      # keyboard focus dies with it), then give the compositor a beat to
      # hand focus on.
      for _ in $(seq 1 40); do
        kill -0 "$panel_pid" 2>/dev/null || break
        sleep 0.05
      done
      sleep 0.2

      if ! hyprctl dispatch focuswindow "address:$target" >/dev/null 2>&1; then
        log "target window $target no longer exists; content left on clipboard"
        exit 0
      fi

      for _ in $(seq 1 20); do
        cur="$(hyprctl activewindow -j 2>/dev/null | jq -r ".address // empty")"
        [[ "$cur" == "$target" ]] && break
        sleep 0.05
      done
      sleep 0.2

      # kitty binds paste to kitty_mod+v (ctrl+shift+v), plain ctrl+v is
      # unbound in a terminal; everything else gets the regular ctrl+v.
      target_class="$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$target" "
        .[] | select(.address==\$addr) | .class
      " | head -n1)"

      if [[ "$target_class" == "kitty" ]]; then
        wtype -M ctrl -M shift -k v -m shift -m ctrl
        log "pasted into $target (class=kitty, ctrl+shift+v)"
      else
        wtype -M ctrl -k v -m ctrl
        log "pasted into $target (class=$target_class, ctrl+v)"
      fi
    ' _ "$target" "$panel_pid" "$log_file" ||
    log "systemd-run failed; content left on clipboard"
else
  log "no target window recorded; content left on clipboard"
fi

kill "$panel_pid" 2>/dev/null || true
