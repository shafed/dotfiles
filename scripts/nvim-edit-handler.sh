#!/usr/bin/env bash
# Handler for nvim-edit://<absolute-path> links from the training logbook.
# Opens the file in the kitty "obsidian" session via kitty-zoxide-session.sh,
# then opens the file in that session's nvim as a new tab.

set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

uri="${1:-}"
log_file="/tmp/nvim-edit-handler.log"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file"
}

log "uri=$uri"

# Strip the scheme and decode percent-encoding -> absolute file path.
path="${uri#nvim-edit://}"
path="$(printf '%b' "${path//%/\\x}")"
path="${path%$'\n'}" # drop any stray trailing newline

if [[ -z "$path" || ! -e "$path" ]]; then
  notify-send "nvim-edit" "File not found: $path" 2>/dev/null || true
  exit 1
fi

session_file="$HOME/dotfiles/kitty/sessions/obsidian.kitty-session"
zoxide_session_script="$HOME/dotfiles/kitty/scripts/kitty-zoxide-session.sh"

newest_kitty() { ls -t /tmp/kitty-* 2>/dev/null | head -n1; }

main_kitty() {
  local pid=""

  if command -v hyprctl >/dev/null 2>&1; then
    pid="$(hyprctl clients -j 2>/dev/null | jq -r '
      [
        .[]?
        | select((.class // "" | test("^kitty$"; "i")) and (.floating == false))
        | .pid
      ][0] // empty
    ')"
    if [[ -n "$pid" && -S "/tmp/kitty-${pid}" ]]; then
      printf "/tmp/kitty-%s" "$pid"
      return 0
    fi
  fi

  find_obsidian_kitty && return 0
  newest_kitty
}

find_obsidian_kitty() {
  local sock=""
  while IFS= read -r sock; do
    [[ -S "$sock" ]] || continue
    if kitty @ --to "unix:$sock" ls 2>/dev/null | jq -e '
      any(.[]?.tabs[]?.windows[]?; .session_name == "obsidian")
    ' >/dev/null; then
      printf "%s" "$sock"
      return 0
    fi
  done < <(ls -t /tmp/kitty-* 2>/dev/null || true)
  return 1
}

obsidian_window_id() {
  local ksock="$1"
  kitty @ --to "unix:$ksock" ls 2>/dev/null | jq -r '
    .[]?.tabs[]?.windows[]?
    | select(.session_name=="obsidian")
    | .id
  ' | head -n1
}

obsidian_nvim_pid() {
  local ksock="$1"
  kitty @ --to "unix:$ksock" ls 2>/dev/null | jq -r '
    .[]?.tabs[]?.windows[]?
    | select(.session_name=="obsidian")
    | .foreground_processes[]?
    | select((.cmdline[0] // "") | test("(^|/)nvim$"))
    | .pid
  ' | head -n1
}

obsidian_nvim_socket() {
  local ksock="$1"
  local pid=""
  local runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local delta=""
  local cand=""
  local sock=""

  pid="$(obsidian_nvim_pid "$ksock")"
  [[ -n "$pid" ]] || return 1

  for delta in 0 1 -1 2 -2 3 -3 4 -4 5 -5; do
    cand="$((pid + delta))"
    sock="$runtime/nvim.${cand}.0"
    [[ -S "$sock" ]] || continue
    if nvim --server "$sock" --remote-expr '1' >/dev/null 2>&1; then
      printf "%s" "$sock"
      return 0
    fi
  done

  return 1
}

open_via_nvim_socket() {
  local ksock="$1"
  local sock=""

  sock="$(obsidian_nvim_socket "$ksock")" || return 1
  log "remote-tab socket=$sock path=$path"
  nvim --server "$sock" --remote-tab "$path"
}

focus_obsidian_window() {
  local ksock="$1"
  local win_id=""

  win_id="$(obsidian_window_id "$ksock")"
  [[ -n "$win_id" ]] || return 1

  log "focus-window socket=$ksock win_id=$win_id"
  kitty @ --to "unix:$ksock" focus-window --match "id:${win_id}"
}

focus_os_window_for_socket() {
  local ksock="$1"
  local pid="${ksock##*/kitty-}"
  local address=""

  command -v hyprctl >/dev/null 2>&1 || return 1
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1

  address="$(hyprctl clients -j 2>/dev/null | jq -r --argjson pid "$pid" '
    .[]? | select(.pid == $pid) | .address
  ' | head -n1)"
  [[ -n "$address" && "$address" != "null" ]] || return 1

  log "hypr-focus socket=$ksock address=$address"
  hyprctl dispatch "hl.dsp.focus({ window = \"address:${address}\" })"
}

vim_single_quote() {
  printf "%s" "$1" | sed "s/'/''/g"
}

shell_single_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
}

open_in_obsidian_window() {
  local ksock="$1"
  local win_id=""
  local nvim_pid=""
  local quoted_path=""
  local keys=""

  win_id="$(obsidian_window_id "$ksock")"
  [[ -n "$win_id" ]] || return 1

  nvim_pid="$(obsidian_nvim_pid "$ksock")"
  if [[ -n "$nvim_pid" ]]; then
    quoted_path="$(vim_single_quote "$path")"
    keys=$'\033'":execute 'tabedit ' . fnameescape('${quoted_path}')"$'\r'
    log "send-vim-command socket=$ksock win_id=$win_id path=$path"
  else
    quoted_path="$(shell_single_quote "$path")"
    keys="nvim -- ${quoted_path}"$'\r'
    log "send-shell-nvim socket=$ksock win_id=$win_id path=$path"
  fi

  printf "%s" "$keys" | kitty @ --to "unix:$ksock" send-text \
    --match "id:${win_id}" \
    --bracketed-paste=disable \
    --stdin
}

# Switch to (or create) the obsidian session through kitty-zoxide-session in the
# main non-floating kitty, not in transient panels such as apps.sh.
ksock="$(main_kitty)"
if [[ -n "$ksock" && -S "$ksock" ]]; then
  log "focus/create obsidian via socket=$ksock"
  KITTY_LISTEN_ON="unix:$ksock" "$zoxide_session_script" --named obsidian >/dev/null 2>&1 || true
else
  log "no kitty socket; exec kitty session=$session_file"
  exec kitty --session "$session_file"
fi

obsidian_ksock=""
for _ in $(seq 1 50); do
  if obsidian_ksock="$(find_obsidian_kitty)"; then
    break
  fi
  sleep 0.2
done

if [[ -z "$obsidian_ksock" ]]; then
  log "failed: obsidian kitty socket not found"
  notify-send "nvim-edit" "Could not find obsidian kitty session." 2>/dev/null || true
  exit 1
fi

if ! open_via_nvim_socket "$obsidian_ksock" >>"$log_file" 2>&1; then
  log "remote-tab failed; falling back to send-text"
  open_in_obsidian_window "$obsidian_ksock" >/dev/null 2>&1 || {
    log "failed: send-text did not run"
    notify-send "nvim-edit" "Could not open file in obsidian nvim." 2>/dev/null || true
    exit 1
  }
fi

kitty @ --to "unix:$obsidian_ksock" action goto_session "$session_file" >/dev/null 2>&1 || true
focus_obsidian_window "$obsidian_ksock" >/dev/null 2>&1 || true
focus_os_window_for_socket "$obsidian_ksock" >/dev/null 2>&1 || true

log "done path=$path"
