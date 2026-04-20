#!/usr/bin/env bash

# Remember how we were invoked so fzf can call us recursively for the preview.
# fzf spawns previews via `sh -c`, so exported bash functions are not visible
# to it — we re-enter this script with --_preview instead.
_TS_SELF="$0"

# Preview renderer: receives one line from fzf and prints the preview body.
# Kept near the top so --_preview can exit before any heavy init runs.
_ts_preview() {
  local line="$1"

  if [[ $line == "[TMUX] "* ]]; then
    # brackets must be escaped inside parameter expansion — otherwise
    # bash treats [TMUX] as a character class (one of T/M/U/X), not
    # the literal prefix "[TMUX]", and the strip silently no-ops.
    local sess="${line#\[TMUX\] }"
    tmux capture-pane -ep -t "$sess" 2>/dev/null | tail -50
    return
  fi

  if [[ ! -d "$line" ]]; then
    echo "Path does not exist: $line"
    echo "(stale zoxide entry — consider: zoxide remove \"$line\")"
    return
  fi

  if command -v eza &>/dev/null; then
    eza --tree --level=2 --color=always --icons=never "$line" 2>/dev/null | head -40
  else
    ls -la --color=always "$line" 2>/dev/null | head -40
  fi

  if [[ -d "$line/.git" ]] && command -v git &>/dev/null; then
    local branch log status
    branch=$(git -C "$line" branch --show-current 2>/dev/null)
    log=$(git -C "$line" log --oneline -5 2>/dev/null)
    status=$(git -C "$line" status -s 2>/dev/null | head -10)

    echo ""
    echo "── git (${branch:-detached}) ──"
    [[ -n "$log" ]] && echo "$log"
    if [[ -n "$status" ]]; then
      echo ""
      echo "── status ──"
      echo "$status"
    fi
  fi
}

# Fast path: when fzf calls us for preview, render and exit immediately.
# Skips sanity_check, config sourcing, log dir creation — none of that is
# needed to render a single preview and it would slow down fzf considerably.
if [[ "${1:-}" == "--_preview" ]]; then
  _ts_preview "${2:-}"
  exit 0
fi

CONFIG_FILE_NAME="tmux-sessionizer.conf"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-sessionizer"
CONFIG_FILE="$CONFIG_DIR/$CONFIG_FILE_NAME"
PANE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-sessionizer"
PANE_CACHE_FILE="$PANE_CACHE_DIR/panes.cache"

# config file example
# ------------------------
# # file: ~/.config/tmux-sessionizer/tmux-sessionizer.conf
# #
# # Directory discovery is done via `zoxide query -l` — no TS_SEARCH_PATHS.
# # Make sure you've cd'd into dirs enough times for zoxide to learn them.
# #
# # TS_SESSION_COMMANDS=(<cmd1> <cmd2>)
# #   Commands to run in high-index windows (69+) via `-s <idx>`.
# #
# # TS_LOG=file        # write logs to TS_LOG_FILE
# # TS_LOG=echo        # print logs to stdout
# # TS_LOG_FILE=<file> # default: ~/.local/share/tmux-sessionizer/tmux-sessionizer.logs
# ------------------------

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

if [[ -f "$CONFIG_FILE_NAME" ]]; then
  source "$CONFIG_FILE_NAME"
fi

if [[ $TS_LOG != "true" ]]; then
  if [[ -z $TS_LOG_FILE ]]; then
    TS_LOG_FILE="$HOME/.local/share/tmux-sessionizer/tmux-sessionizer.logs"
  fi

  mkdir -p "$(dirname "$TS_LOG_FILE")"
fi

log() {
  if [[ -z $TS_LOG ]]; then
    return
  elif [[ $TS_LOG == "echo" ]]; then
    echo "$*"
  elif [[ $TS_LOG == "file" ]]; then
    echo "$*" >>"$TS_LOG_FILE"
  fi
}

session_idx=""
session_cmd=""
user_selected=""
split_type=""
VERSION="0.1.0-zoxide"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
  -h | --help)
    echo "Usage: tmux-sessionizer [OPTIONS] [QUERY_OR_PATH]"
    echo "Options:"
    echo "  -h, --help             Display this help message"
    echo "  -s, --session <n>      session command index."
    echo "  --vsplit               Create vertical split (horizontal layout) for session command"
    echo "  --hsplit               Create horizontal split (vertical layout) for session command"
    echo "  -v, --version          Show version"
    echo ""
    echo "QUERY_OR_PATH: an existing directory path, or a zoxide query (e.g. 'nvim-conf')"
    exit 0
    ;;
  -s | --session)
    session_idx="$2"
    if [[ -z $session_idx ]]; then
      echo "Session index cannot be empty"
      exit 1
    fi

    if [[ -z $TS_SESSION_COMMANDS ]]; then
      echo "TS_SESSION_COMMANDS is not set.  Must have a command set to run when switching to a session"
      exit 1
    fi

    if [[ -z "$session_idx" || "$session_idx" -lt 0 || "$session_idx" -ge "${#TS_SESSION_COMMANDS[@]}" ]]; then
      echo "Error: Invalid index. Please provide an index between 0 and $((${#TS_SESSION_COMMANDS[@]} - 1))."
      exit 1
    fi

    session_cmd="${TS_SESSION_COMMANDS[$session_idx]}"

    shift
    ;;
  --vsplit)
    split_type="vsplit"
    ;;
  --hsplit)
    split_type="hsplit"
    ;;
  -v | --version)
    echo "tmux-sessionizer version $VERSION"
    exit 0
    ;;
  *)
    user_selected="$1"
    ;;
  esac
  shift
done

log "tmux-sessionizer($VERSION): idx=$session_idx cmd=$session_cmd user_selected=$user_selected split_type=$split_type log=$TS_LOG log_file=$TS_LOG_FILE"

# Validate split options are only used with session commands
if [[ -n "$split_type" && -z "$session_idx" ]]; then
  echo "Error: --vsplit and --hsplit can only be used with -s/--session option"
  exit 1
fi

sanity_check() {
  if ! command -v tmux &>/dev/null; then
    echo "tmux is not installed. Please install it first."
    exit 1
  fi

  if ! command -v fzf &>/dev/null; then
    echo "fzf is not installed. Please install it first."
    exit 1
  fi

  if ! command -v zoxide &>/dev/null; then
    echo "zoxide is not installed. Please install it first."
    exit 1
  fi
}

switch_to() {
  if [[ -z $TMUX ]]; then
    log "attaching to session $1"
    tmux attach-session -t "$1"
  else
    log "switching to session $1"
    tmux switch-client -t "$1"
  fi
}

has_session() {
  tmux has-session -t="=$1" 2>/dev/null
}

hydrate() {
  if [[ ! -z $session_cmd ]]; then
    log "skipping hydrate for $1 -- using \"$session_cmd\" instead"
    return
  elif [ -f "$2/.tmux-sessionizer" ]; then
    log "sourcing(local) $2/.tmux-sessionizer"
    tmux send-keys -t "$1" "source $2/.tmux-sessionizer" c-M
  elif [ -f "$HOME/.tmux-sessionizer" ]; then
    log "sourcing(global) $HOME/.tmux-sessionizer"
    tmux send-keys -t "$1" "source $HOME/.tmux-sessionizer" c-M
  fi
}

is_tmux_running() {
  tmux_running=$(pgrep tmux)

  if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
    return 1
  fi
  return 0
}

init_pane_cache() {
  mkdir -p "$PANE_CACHE_DIR"
  touch "$PANE_CACHE_FILE"
}

get_pane_id() {
  local session_idx="$1"
  local split_type="$2"
  init_pane_cache
  grep "^${session_idx}:${split_type}:" "$PANE_CACHE_FILE" | cut -d: -f3
}

set_pane_id() {
  local session_idx="$1"
  local split_type="$2"
  local pane_id="$3"
  init_pane_cache

  # Remove existing entry if it exists
  grep -v "^${session_idx}:${split_type}:" "$PANE_CACHE_FILE" >"${PANE_CACHE_FILE}.tmp" 2>/dev/null || true
  mv "${PANE_CACHE_FILE}.tmp" "$PANE_CACHE_FILE"

  # Add new entry
  echo "${session_idx}:${split_type}:${pane_id}" >>"$PANE_CACHE_FILE"
}

cleanup_dead_panes() {
  init_pane_cache
  local temp_file="${PANE_CACHE_FILE}.tmp"

  while IFS=: read -r idx split pane_id; do
    if tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -q "^${pane_id}$"; then
      echo "${idx}:${split}:${pane_id}" >>"$temp_file"
    fi
  done <"$PANE_CACHE_FILE"

  mv "$temp_file" "$PANE_CACHE_FILE" 2>/dev/null || touch "$PANE_CACHE_FILE"
}

sanity_check

# Directory discovery via zoxide + existing tmux sessions
find_dirs() {
  # list TMUX sessions first (minus the current one)
  if [[ -n "${TMUX}" ]]; then
    current_session=$(tmux display-message -p '#S')
    tmux list-sessions -F "[TMUX] #{session_name}" 2>/dev/null | grep -vFx "[TMUX] $current_session"
  else
    tmux list-sessions -F "[TMUX] #{session_name}" 2>/dev/null
  fi

  # then list directories from zoxide's database (frecency-ordered)
  zoxide query -l
}

handle_session_cmd() {
  log "executing session command $session_cmd with index $session_idx split_type=$split_type"
  if ! is_tmux_running; then
    echo "Error: tmux is not running.  Please start tmux first before using session commands."
    exit 1
  fi

  current_session=$(tmux display-message -p '#S')

  if [[ -n "$split_type" ]]; then
    handle_split_session_cmd "$current_session"
  else
    handle_window_session_cmd "$current_session"
  fi
  exit 0
}

handle_window_session_cmd() {
  local current_session="$1"
  start_index=$((69 + $session_idx))
  target="$current_session:$start_index"

  log "target: $target command $session_cmd has-session=$(tmux has-session -t="$target" 2>/dev/null)"
  if tmux has-session -t="$target" 2>/dev/null; then
    switch_to "$target"
  else
    log "executing session command: tmux neww -dt $target $session_cmd"
    tmux neww -dt $target "$session_cmd"
    hydrate "$target" "$selected"
    tmux select-window -t $target
  fi
}

handle_split_session_cmd() {
  local current_session="$1"
  cleanup_dead_panes

  # Check if pane already exists
  local existing_pane_id=$(get_pane_id "$session_idx" "$split_type")

  if [[ -n "$existing_pane_id" ]] && tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -q "^${existing_pane_id}$"; then
    log "switching to existing pane $existing_pane_id"
    tmux select-pane -t "$existing_pane_id"
    if [[ -z $TMUX ]]; then
      tmux attach-session -t "$current_session"
    else
      tmux switch-client -t "$current_session"
    fi
  else
    # Create new split
    local split_flag=""
    if [[ "$split_type" == "vsplit" ]]; then
      split_flag="-h" # horizontal layout (vertical split)
    else
      split_flag="-v" # vertical layout (horizontal split)
    fi

    log "creating new split: tmux split-window $split_flag -c $(pwd) $session_cmd"
    local new_pane_id=$(tmux split-window $split_flag -c "$(pwd)" -P -F "#{pane_id}" "$session_cmd")

    if [[ -n "$new_pane_id" ]]; then
      set_pane_id "$session_idx" "$split_type" "$new_pane_id"
      log "created pane $new_pane_id for session_idx=$session_idx split_type=$split_type"
    fi
  fi
}

if [[ ! -z $session_cmd ]]; then
  handle_session_cmd
elif [[ ! -z $user_selected ]]; then
  # If it's a real directory, use it directly; otherwise ask zoxide to resolve it
  if [[ -d "$user_selected" ]]; then
    selected="$user_selected"
  else
    selected=$(zoxide query "$user_selected" 2>/dev/null)
    if [[ -z $selected ]]; then
      echo "zoxide: no match for '$user_selected'"
      exit 1
    fi
  fi
else
  # Build preview command with properly-quoted script path, so fzf can
  # re-invoke this very script in --_preview mode regardless of which
  # shell it uses internally (typically `sh`, not bash).
  _preview_cmd="$(printf '%q' "$_TS_SELF") --_preview {}"

  selected=$(find_dirs | fzf \
    --layout=reverse \
    --preview "$_preview_cmd" \
    --preview-window=right:55%:wrap \
    --prompt='project> ' \
    --header='enter: open | ctrl-c: cancel')
fi

if [[ -z $selected ]]; then
  exit 0
fi

if [[ "$selected" =~ ^\[TMUX\]\ (.+)$ ]]; then
  selected="${BASH_REMATCH[1]}"
fi

selected_name=$(basename "$selected" | tr . _)

if ! has_session "$selected_name"; then
  tmux new-session -ds "$selected_name" -c "$selected"
  hydrate "$selected_name" "$selected"
fi

switch_to "$selected_name"
