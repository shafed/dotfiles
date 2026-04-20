#!/usr/bin/env bash

# Filename: ~/github/dotfiles-latest/kitty/scripts/tmux-list-sessions.sh
# Shows open tmux sessions in fzf and switches to the selected one.
# Adds a vim-like "mode":
# - Normal mode (default): j/k move, d closes, enter opens, i enters insert mode, esc quits
# - Insert mode: type to filter, enter opens, esc returns to normal mode

set -euo pipefail

default_mode="insert"

set_cursor_block() {
  printf '\e[2 q' >/dev/tty
}

set_cursor_bar() {
  printf '\e[6 q' >/dev/tty
}

trap 'set_cursor_bar' EXIT

base_color="\033[1;38;2;169;182;101m"
current_color="\033[1;38;2;231;138;78m"
reset_color="\033[0m"

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is not installed or not in PATH."
  echo "Install: sudo pacman -S fzf"
  exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is not installed or not in PATH."
  echo "Install: sudo pacman -S tmux"
  exit 1
fi

# Returns the name of the currently attached session (empty if none).
current_session() {
  if [[ -n "${TMUX:-}" ]]; then
    tmux display-message -p '#S' 2>/dev/null || true
  fi
}

build_menu_lines() {
  local cur_session=""
  cur_session="$(current_session)"

  # list-sessions format: name, last_attached (epoch), session_path
  tmux list-sessions -F '#{session_name}|#{session_last_attached}|#{session_path}' 2>/dev/null |
    sort -t'|' -k2 -rn |
    awk -F'|' -v home="$HOME" -v cur="$cur_session" \
      -v base_color="$base_color" -v current_color="$current_color" \
      -v reset_color="$reset_color" '
      {
        name=$1
        path=$3
        if (home != "" && index(path, home) == 1)
          path = "~" substr(path, length(home) + 1)
        is_current = (name == cur)
        color = is_current ? current_color : base_color
        printf "%d\t%s\t%s%s%s  %s\n", NR, name, color, name, reset_color, path
      }
    '
}

close_session() {
  local name="$1"
  local cur_session=""
  cur_session="$(current_session)"

  if [[ "$name" == "$cur_session" ]]; then
    # Can't kill the current session directly — switch away first.
    local other=""
    other="$(tmux list-sessions -F '#{session_name}' 2>/dev/null |
      grep -v "^${name}$" | head -n1 || true)"
    if [[ -n "$other" ]]; then
      tmux switch-client -t "=$other" 2>/dev/null || true
    fi
  fi

  tmux kill-session -t "=$name" 2>/dev/null || true
}

switch_to_session() {
  local name="$1"
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "=$name"
  else
    tmux attach-session -t "=$name"
  fi
}

mode="$default_mode"
fzf_start_pos=""

while true; do
  menu_lines="$(build_menu_lines || true)"
  if [[ -z "${menu_lines:-}" ]]; then
    echo "No tmux sessions found."
    exit 1
  fi

  fzf_out=""
  fzf_rc=0

  if [[ "$mode" == "normal" ]]; then
    set_cursor_block
    set +e
    fzf_start_pos_opt=()
    if [[ -n "${fzf_start_pos:-}" && "$fzf_start_pos" -gt 1 ]]; then
      fzf_start_action="down"
      for ((i = 3; i <= fzf_start_pos; i++)); do
        fzf_start_action+="+down"
      done
      fzf_start_pos_opt=(--bind "result:${fzf_start_action}")
    fi
    fzf_out="$(
      printf "%s\n" "$menu_lines" |
        fzf --ansi --height=100% --reverse \
          --header="Normal: j/k move, d close, enter open, i insert, esc quit" \
          --prompt="List tmux Sessions > " \
          --no-multi --disabled \
          --with-nth=3.. \
          --expect=enter,d,i,esc \
          --bind 'j:down,k:up' \
          --bind 'enter:accept,d:accept,i:accept' \
          --bind 'esc:abort' \
          --no-clear \
          ${fzf_start_pos_opt[@]+"${fzf_start_pos_opt[@]}"}
    )"
    fzf_rc=$?
    fzf_start_pos=""
    set -e
  else
    set_cursor_bar
    set +e
    fzf_out="$(
      printf "%s\n" "$menu_lines" |
        fzf --ansi --height=100% --reverse \
          --header="Insert: type to filter, enter open, esc normal" \
          --prompt="List tmux Sessions > " \
          --no-multi \
          --with-nth=3.. \
          --expect=enter,esc \
          --bind 'enter:accept' \
          --bind 'esc:abort' \
          --no-clear
    )"
    fzf_rc=$?
    set -e
  fi

  if [[ $fzf_rc -ne 0 && -z "${fzf_out:-}" ]]; then
    key="esc"
    sel=""
  else
    key="$(printf "%s\n" "$fzf_out" | head -n1)"
    sel="$(printf "%s\n" "$fzf_out" | sed -n '2p' || true)"
  fi

  selected_name=""
  selected_index=""
  if [[ -n "${sel:-}" ]]; then
    selected_index="$(printf "%s" "$sel" | awk -F'\t' '{print $1}')"
    selected_name="$(printf "%s" "$sel" | awk -F'\t' '{print $2}')"
  fi

  if [[ "$mode" == "insert" && "$key" == "esc" ]]; then
    mode="normal"
    continue
  fi

  if [[ "$mode" == "normal" && "$key" == "esc" ]]; then
    exit 0
  fi

  if [[ "$mode" == "normal" && "$key" == "i" ]]; then
    mode="insert"
    continue
  fi

  if [[ -z "${selected_name:-}" ]]; then
    if [[ "$mode" == "normal" ]]; then
      exit 0
    fi
    mode="normal"
    continue
  fi

  if [[ "$mode" == "normal" && "$key" == "d" ]]; then
    if [[ "${selected_index:-}" =~ ^[0-9]+$ ]]; then
      total_lines="$(printf "%s\n" "$menu_lines" | awk 'END{print NR}')"
      if [[ -n "${total_lines:-}" && "$selected_index" -ge "$total_lines" ]]; then
        fzf_start_pos=$((selected_index - 1))
      else
        fzf_start_pos=$selected_index
      fi
      if [[ "$fzf_start_pos" -lt 1 ]]; then
        fzf_start_pos=1
      fi
    fi
    close_session "$selected_name"
    continue
  fi

  if [[ "$key" == "enter" ]]; then
    switch_to_session "$selected_name"
    exit 0
  fi

  if [[ "$mode" == "insert" ]]; then
    mode="normal"
    continue
  fi

  exit 0
done
