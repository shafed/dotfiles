#!/usr/bin/env bash

# Filename: ~/dotfiles/kitty/scripts/kitty-list-sessions.sh
# Shows open kitty sessions in fzf and switches using goto_session.
# Adds a vim-like "mode":
# - Normal mode (default): j/k move, d closes, enter opens, i enters insert mode, esc quits
# - Insert mode: type to filter, enter opens, esc returns to normal mode
#
# Requires: kitty with allow_remote_control yes + listen_on unix:/tmp/kitty-{kitty_pid}
# Shown as a kitty quick-access panel (QAT); inside it $KITTY_LISTEN_ON points
# at the panel instance, so the script is re-pointed at the main kitty socket
# (--qat) before any `kitten @` call. Plain invocation = QAT launcher.

set -euo pipefail

default_mode="normal"

script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
kitty_sessions_dir="$HOME/dotfiles/kitty/sessions"
transient_sessions_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kitty-sessions"

set_cursor_block() {
  # DECSCUSR: steady block
  printf '\e[2 q' >/dev/tty
}

set_cursor_bar() {
  # DECSCUSR: steady bar
  printf '\e[6 q' >/dev/tty
}

# Always restore to bar on exit
trap 'set_cursor_bar' EXIT

# Gruvbox Material colors from ../current-theme.conf.
base_color=$'\033[1;38;2;169;182;101m'   # color2: #a9b665
current_color=$'\033[1;38;2;231;138;78m' # color3: #e78a4e
reset_color=$'\033[0m'

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is not installed or not in PATH."
  echo "Install: sudo pacman -S fzf"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not installed or not in PATH."
  echo "Install: sudo pacman -S jq"
  exit 1
fi

dotfiles_dir="$HOME/dotfiles"
# Shared QAT helpers (main_kitty_socket, launch_qat) + gruvbox fzf colors.
# shellcheck source=../../scripts/lib.sh
source "$dotfiles_dir/scripts/lib.sh"
qat_group="list-sessions"

# QAT dispatch: `--qat` runs the picker inside the quick-access panel, talking
# to the MAIN kitty's socket (inside the panel $KITTY_LISTEN_ON points at the
# panel's own instance, where goto/close_session would act on the wrong kitty).
# Plain invocation (kanata apps+c) is the launcher: show the picker as a panel.
if [[ "${1:-}" == "--qat" ]]; then
  qat_sock="$(main_kitty_socket)" || {
    echo "No main kitty socket found."
    exit 1
  }
  export KITTY_LISTEN_ON="unix:${qat_sock}"
else
  launch_qat "$qat_group" /usr/bin/env bash "$script_path" --qat
  exit 0
fi

# Resolve a session name to a session file path.
# Checks the transient cache first, then the named sessions dir.
session_file_for_name() {
  local name="$1"
  local transient_file="${transient_sessions_dir}/${name}.kitty-session"
  local named_file="${kitty_sessions_dir}/${name}.kitty-session"

  if [[ -f "$transient_file" ]]; then
    printf "%s" "$transient_file"
  elif [[ -f "$named_file" ]]; then
    printf "%s" "$named_file"
  else
    # Fallback: pass the name directly (goto_session accepts session names too)
    printf "%s" "$name"
  fi
}

build_menu_lines() {
  local sessions_tsv=""
  sessions_tsv="$(
    kitten @ ls 2>/dev/null | jq -r '
      [
        .[] as $os
        | $os.tabs[] as $tab
        | $tab.windows[]?
        | select(.session_name != null and .session_name != "")
          | {
              session_name: .session_name,
              pwd: (.env.PWD // .cwd),
              os_focused: ($os.is_focused // false),
              tab_focused: ($tab.is_focused // false),
              last_focused_at: (.last_focused_at // 0)
            }
        ]
      # Deduplicate by session_name, pick the focused window, sort by recency
      | sort_by(.session_name)
      | group_by(.session_name)
      | map({
          session_last_focused_at: (map(.last_focused_at) | max),
          pick: (
            if (map(.os_focused and .tab_focused) | any) then
              (map(select(.os_focused and .tab_focused)) | .[0])
            else
              .[0]
            end
          )
        })
      | map(.pick + {session_last_focused_at: .session_last_focused_at})
      # Most recent sessions first, then name for stable ordering
      | sort_by(-.session_last_focused_at, .session_name)
        | .[]
        | [(.session_name|tostring), (.os_focused|tostring), (.tab_focused|tostring), (.pwd|tostring)]
        | @tsv
    '
  )"

  if [[ -z "${sessions_tsv:-}" ]]; then
    return 1
  fi

  # idx<TAB>session_name<TAB>pretty_display
  printf "%s\n" "$sessions_tsv" | awk -F'\t' \
    -v home="${HOME}" \
    -v base_color="${base_color}" \
    -v current_color="${current_color}" \
    -v reset_color="${reset_color}" '
  {
    session_name=$1
    os_focused=$2
    tab_focused=$3
    path=$4
    if (home != "" && index(path, home) == 1) {
      path = "~" substr(path, length(home) + 1)
    }
    idx=NR
    if (os_focused == "true" && tab_focused == "true") {
      name_color=current_color
    } else {
      name_color=base_color
    }
    printf "%d\t%s\t%s%s%s  %s\n", idx, session_name, name_color, session_name, reset_color, path
  }'
}

close_session() {
  local name="$1"
  # Use kitten @ close_session to close by session name
  kitten @ action close_session "$name" >/dev/null 2>&1 || true
}

switch_to_session() {
  local name="$1"
  local file=""
  file="$(session_file_for_name "$name")"
  goto_kitty_session "$file"
}

# Set the startup mode
mode="$default_mode"
fzf_start_pos=""

while true; do
  menu_lines="$(build_menu_lines || true)"
  if [[ -z "${menu_lines:-}" ]]; then
    echo "No kitty sessions found."
    exit 1
  fi

  fzf_out=""
  fzf_rc=0

  if [[ "$mode" == "normal" ]]; then
    # Normal mode:
    # - Search disabled (typing doesn't filter)
    # - j/k move
    # - d closes session
    # - enter opens session
    # - i enters insert mode
    # - esc quits
    # - --no-clear avoids a visible screen "flash"
    #   - We exit one fzf instance and immediately start another when switching modes
    #   - Prevents fzf from clearing/restoring the screen on exit
    set_cursor_block
    set +e
    fzf_start_pos_opt=()
    if [[ -n "${fzf_start_pos:-}" && "$fzf_start_pos" -gt 1 ]]; then
      fzf_start_action="down"
      for ((i = 3; i <= fzf_start_pos; i++)); do
        fzf_start_action+="+down"
      done
      # Workaround for older fzf where start:* actions are ignored.
      # Based on https://github.com/junegunn/fzf/issues/4559
      fzf_start_pos_opt=(--bind "result:${fzf_start_action}")
    fi
    fzf_out="$(
      printf "%s\n" "$menu_lines" |
        fzf --ansi --height=100% --reverse \
          --header="Normal: j/k move, d close, enter open, i insert, esc quit" \
          --prompt="List Open Kitty Sessions > " \
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
    # Insert mode:
    # - Search enabled (type to filter)
    # - enter opens session
    # - esc returns to normal mode
    # - --no-clear avoids a visible screen "flash"
    #   - We exit one fzf instance and immediately start another when switching modes
    #   - Prevents fzf from clearing/restoring the screen on exit
    set_cursor_bar
    set +e
    fzf_out="$(
      printf "%s\n" "$menu_lines" |
        fzf --ansi --height=100% --reverse \
          --header="Insert: type to filter, enter open, esc normal" \
          --prompt="List Open Kitty Sessions > " \
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

  # If fzf aborted and gave no output, treat it like "esc"
  if [[ $fzf_rc -ne 0 && -z "${fzf_out:-}" ]]; then
    key="esc"
    sel=""
  else
    key="$(printf "%s\n" "$fzf_out" | head -n1)"
    sel="$(printf "%s\n" "$fzf_out" | sed -n '2p' || true)"
  fi

  # Selection line is: idx<TAB>session_name<TAB>pretty_display
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
    # Nothing selected (likely esc)
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

  # Fallback behavior:
  # - In insert mode, abort returns here -> go back to normal
  # - In normal mode, unknown key -> exit
  if [[ "$mode" == "insert" ]]; then
    mode="normal"
    continue
  fi

  exit 0
done
