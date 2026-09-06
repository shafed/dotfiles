#!/usr/bin/env bash
# Turn the currently focused GUI text field into a fullscreen Neovim editor.
#
# Super+Shift+E (hypr/modules/binds.lua) selects/copies the current field,
# opens it in the same fullscreen kitty QAT used by the scratch editor, and on
# any Neovim exit focuses the original Hyprland window and replaces the field
# with the edited text. Re-triggering the hotkey while the QAT exists only
# hides/shows that same editor; it never recaptures a different field mid-edit.

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$script_path")"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/nvim-textarea"
text_file="$cache_dir/text.txt"
target_file="$cache_dir/target.json"
pid_file="$cache_dir/editor.pid"
log_file="$cache_dir/textarea.log"
textarea_group="textarea"
textarea_qat_config="$HOME/github/dotfiles/kitty/quick-access-terminal-scratch.conf"

mkdir -p "$cache_dir"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file"; }

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -t 2500 "Neovim textarea" "$1"
}

active_window_json() {
  hyprctl -j activewindow 2>/dev/null || printf '{}\n'
}

active_address() {
  active_window_json | jq -r '.address // empty' 2>/dev/null
}

kanata_layout() {
  hyprctl -j devices 2>/dev/null | jq -r '
    .keyboards[]? | select(.name == "kanata") | .active_layout_index
  ' 2>/dev/null | head -n1
}

editor_alive() {
  [[ -s "$pid_file" ]] || return 1
  local pid
  pid="$(<"$pid_file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

focus_target() {
  local target="$1" i
  [[ -n "$target" ]] || return 1

  hyprctl dispatch "hl.dsp.focus({ window = \"address:${target}\" })" >/dev/null 2>&1 || return 1
  for i in {1..20}; do
    [[ "$(active_address)" == "$target" ]] && return 0
    sleep 0.05
  done
  return 1
}

finish_editor() {
  local panel_pid="$PPID"
  local target="" layout="" text="" paste_ok=0

  [[ -f "$target_file" ]] && target="$(jq -r '.address // empty' "$target_file" 2>/dev/null || true)"
  [[ -f "$target_file" ]] && layout="$(jq -r '.layout // empty' "$target_file" 2>/dev/null || true)"
  [[ -f "$text_file" ]] && text="$(<"$text_file")"

  # Keep the final text in the clipboard too. This both powers the synthetic
  # paste and gives a recovery path if the source window disappeared.
  if [[ -n "$text" ]]; then
    printf '%s' "$text" | wl-copy
  else
    wl-copy --clear 2>/dev/null || true
  fi

  if focus_target "$target"; then
    # Replace the entire original field. For an empty result BackSpace is used
    # because pasting an empty clipboard does not reliably delete a selection
    # in every toolkit.
    wtype -M ctrl -k a -m ctrl
    sleep 0.03
    if [[ -n "$text" ]]; then
      wtype -M ctrl -k v -m ctrl
    else
      wtype -k BackSpace
    fi
    paste_ok=1
    log "replaced textarea in $target"
  else
    log "target window unavailable: ${target:-<none>}"
    notify "Target window is gone; edited text is left in the clipboard and $text_file"
  fi

  # Neovim normal mode forces the kanata device to US. Put the application
  # back on the layout it had when the textarea editor was invoked.
  if [[ "$layout" =~ ^[0-9]+$ ]]; then
    hyprctl switchxkblayout kanata "$layout" >/dev/null 2>&1 || true
  fi

  if (( paste_ok )); then
    : >"$text_file"
  fi
  rm -f "$target_file" "$pid_file"

  # Same lifecycle as nvim-scratch-quit.sh: terminate the QAT host after the
  # editor exits rather than merely hiding it, so the next invocation captures
  # a fresh field.
  kill "$panel_pid" 2>/dev/null || true
}

run_editor() {
  printf '%s\n' "$$" >"$pid_file"

  # The buffer is always persisted on exit, including the user's fast :q!
  # mappings, so every way of leaving this temporary editor means "apply".
  # text.txt deliberately avoids the markdown mkview/loadview autocmds, which
  # would otherwise restore a cursor position from an earlier textarea use.
  nvim "+normal! G$" +startinsert "+autocmd VimLeavePre * silent! write" -- "$text_file"
  finish_editor
}

launch_editor() {
  local dep window target class layout

  # If a textarea editor already exists, this is only a hide/show request.
  # Capturing again here would overwrite its draft with the QAT's own window.
  if editor_alive; then
    qat_config="$textarea_qat_config"
    run_qat_panel "$textarea_group" /usr/bin/env bash "$script_path" --run >/dev/null 2>&1 || true
    return 0
  fi
  rm -f "$pid_file" "$target_file"

  for dep in hyprctl jq wtype wl-copy wl-paste; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      notify "Missing dependency: $dep"
      return 1
    fi
  done

  # QATs are hosted by the main kitty instance. Unlike session pickers this
  # action should not create an unrelated kitty window just to edit a field.
  if [[ -z "$(main_kitty_socket || true)" ]]; then
    notify "Main kitty is not running"
    return 0
  fi

  window="$(active_window_json)"
  target="$(jq -r '.address // empty' <<<"$window")"
  class="$(jq -r '.class // empty' <<<"$window")"
  layout="$(kanata_layout)"
  [[ "$layout" =~ ^[0-9]+$ ]] || layout=0

  if [[ -z "$target" ]]; then
    notify "No focused Hyprland window"
    return 0
  fi

  # Ctrl+A has terminal semantics rather than "select field", so invoking the
  # textarea bridge from kitty would be destructive. Neovim is already the
  # right editor there anyway.
  if [[ "${class,,}" == "kitty" ]]; then
    notify "Textarea mode is for GUI text fields, not kitty"
    return 0
  fi

  jq -cn --arg address "$target" --arg class "$class" --argjson layout "$layout" \
    '{address:$address,class:$class,layout:$layout}' >"$target_file"

  # Clear first so Ctrl+C on a genuinely empty input cannot leave an unrelated
  # old clipboard value looking like the field contents.
  wl-copy --clear 2>/dev/null || true
  wtype -M ctrl -k a -k c -m ctrl
  sleep 0.10
  if ! wl-paste --no-newline >"$text_file" 2>/dev/null; then
    : >"$text_file"
  fi

  log "captured textarea from $class $target"

  # Do not use launch_qat(): it forces the keyboard to US before Neovim starts.
  # Starting through run_qat_panel lets the existing Neovim layout autocmds see
  # the application's current layout, while finish_editor restores it on exit.
  qat_config="$textarea_qat_config"
  if ! run_qat_panel "$textarea_group" /usr/bin/env bash "$script_path" --run; then
    log "failed to launch textarea QAT"
    notify "Could not open the Neovim textarea panel"
    rm -f "$target_file" "$pid_file"
    return 1
  fi
}

case "${1:-}" in
--run)
  run_editor
  ;;
*)
  launch_editor
  ;;
esac
