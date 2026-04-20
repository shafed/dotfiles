#!/usr/bin/env bash

# Filename: ~/github/dotfiles-latest/kitty/scripts/tmux-zoxide-session.sh
# Select a zoxide entry and switch to an existing tmux session,
# or create it if it doesn't exist.
#
# Also supports:
#   - SSH host entries from ~/.ssh/config (and Include files).
#     SSH entries are shown with a "ssh-" prefix.
#   - Named sessions from *.tmux-session files in tmux-sessions/.
#     These are shown with a "s-" prefix.
#
#     .tmux-session format:
#       dir ~/path/to/dir   # working directory (required)
#       cmd nvim            # command sent via send-keys + Enter (optional)
#       keys s              # extra keys sent after cmd (optional, e.g. Enter, Escape)

set -euo pipefail

script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
tmux_sessions_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/tmux-sessions"
work_env_file="$HOME/github/dotfiles-private/work/work-env.sh"

if [[ -f "$work_env_file" ]]; then
  # shellcheck disable=SC1090
  source "$work_env_file"
fi

require_cmd() {
  local cmd="$1"
  local install_hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd is not installed or not in PATH."
    echo "$install_hint"
    exit 1
  fi
}

require_cmd fzf "Install: sudo pacman -S fzf"
require_cmd zoxide "Install: sudo pacman -S zoxide"
require_cmd tmux "Install: sudo pacman -S tmux"

normalize_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p"
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$p" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
    return 0
  fi

  printf "%s" "$p"
}

work_main_dir="${WORK_MAIN_DIR:-}"
if [[ -n "${work_main_dir:-}" ]]; then
  work_main_dir="$(normalize_path "$work_main_dir")"
fi

base_color="\033[1;38;2;169;182;101m"
reset_color="\033[0m"

bump_zoxide_score() {
  local path="$1"
  zoxide add -- "$path" >/dev/null 2>&1 || true
}

# tmux session names cannot contain dots or colons; replace with underscores.
sanitize_session_name() {
  printf "%s" "$1" | tr '.:' '_'
}

# Find an existing tmux session whose start directory matches the target path.
find_session_by_path() {
  local target="$1"
  local name=""
  local pwd=""
  local real=""

  while IFS=$'\t' read -r name pwd; do
    [[ -z "$name" || -z "$pwd" ]] && continue
    [[ ! -d "$pwd" ]] && continue
    real="$(normalize_path "$pwd")"
    if [[ "$real" == "$target" ]]; then
      printf "%s" "$name"
      return 0
    fi
  done < <(
    tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null \
      | awk -F'|' '{print $1"\t"$2}' || true
  )

  return 1
}

session_exists() {
  local name="$1"
  tmux has-session -t "=$name" 2>/dev/null
}

print_menu_lines() {
  # Named tmux-session entries come first so they're easy to spot / filter.
  print_tmux_session_menu_lines

  zoxide query -l 2>/dev/null | awk -v OFS='\t' -v work_dir="${work_main_dir}" -v color="${base_color}" -v reset="${reset_color}" '{
    path=$0
    if (work_dir != "" && (path == work_dir || index(path, work_dir "/") == 1)) next
    n=split(path, parts, "/")
    base=parts[n]
    if (base == "") base=path
    printf "%s\t%s%s%s  %s\n", path, color, base, reset, path
  }'

  print_ssh_menu_lines
}

# Parse a single .tmux-session file and emit one fzf menu line.
# Format:
#   dir ~/path    # working directory
#   cmd nvim      # command sent via send-keys + Enter
#   keys s        # extra keys sent after cmd (e.g. Enter, Escape)
parse_tmux_session_file() {
  local file="$1"
  local name=""
  local dir=""
  local cmd=""
  local keys=""
  local line=""

  name="$(basename "$file" .tmux-session)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^dir[[:space:]]+(.+)$ ]]; then
      dir="${BASH_REMATCH[1]}"
      dir="${dir/#\~/$HOME}"
    elif [[ "$line" =~ ^cmd[[:space:]]+(.+)$ ]]; then
      cmd="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^keys[[:space:]]+(.+)$ ]]; then
      keys="${BASH_REMATCH[1]}"
    fi
  done <"$file"

  local display_dir="${dir:-~}"
  local label="${name}"
  # Pack fields with ASCII unit separator (0x1f).
  local packed="${name}"$'\x1f'"${dir}"$'\x1f'"${cmd}"$'\x1f'"${keys}"
  printf "session:%s\t%b%s%b  %s\n" \
    "$packed" \
    "${base_color}" "$label" "${reset_color}" \
    "$display_dir"
}

print_tmux_session_menu_lines() {
  [[ -d "$tmux_sessions_dir" ]] || return 0
  local f=""
  for f in "$tmux_sessions_dir"/*.tmux-session; do
    [[ -f "$f" ]] || continue
    parse_tmux_session_file "$f"
  done
}

collect_ssh_config_files() {
  local root_config="$HOME/.ssh/config"
  local file=""
  local line=""
  local includes=""
  local pattern=""
  local match=""
  local queue=()
  local files=()
  local processed="|"
  local old_nullglob=""

  if [[ ! -f "$root_config" ]]; then
    return 0
  fi

  queue+=("$root_config")

  old_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob

  while ((${#queue[@]})); do
    file="${queue[0]}"
    queue=("${queue[@]:1}")

    case "$processed" in
    *"|${file}|"*)
      continue
      ;;
    esac

    processed+="${file}|"
    if [[ ! -f "$file" ]]; then
      continue
    fi

    files+=("$file")

    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      if [[ "$line" =~ ^[[:space:]]*Include[[:space:]]+(.+) ]]; then
        includes="${BASH_REMATCH[1]}"
        for pattern in $includes; do
          pattern="${pattern/#~/$HOME}"
          for match in $pattern; do
            if [[ -f "$match" ]]; then
              queue+=("$match")
            fi
          done
        done
      fi
    done <"$file"
  done

  eval "$old_nullglob"

  printf "%s\n" "${files[@]}"
}

print_ssh_menu_lines() {
  local config_files=()
  local host=""
  local label=""

  while IFS= read -r host; do
    config_files+=("$host")
  done < <(collect_ssh_config_files)

  if ((${#config_files[@]} == 0)); then
    return 0
  fi

  while IFS= read -r host; do
    [[ -z "$host" ]] && continue
    label="ssh-${host}"
    printf "%s\t%b%s%b\n" "ssh:${host}" "${base_color}" "$label" "${reset_color}"
  done < <(
    awk '
      {
        sub(/[ \t]*#.*/, "")
        if (tolower($1) == "host") {
          for (i = 2; i <= NF; i++) {
            h = $i
            if (h ~ /^[!]/) continue
            if (h ~ /[\\*?]/) continue
            print h
          }
        }
      }
    ' "${config_files[@]}" | sort -u
  )
}

if [[ "${1:-}" == "--reload" ]]; then
  print_menu_lines
  exit 0
fi

focus_or_launch_dir() {
  local selected_path="$1"
  local selected_real=""
  local base=""
  local safe_base=""
  local session_name=""
  local existing_session=""
  local suffix=2

  if [[ ! -d "$selected_path" ]]; then
    echo "Directory not found: $selected_path"
    exit 1
  fi

  selected_real="$(normalize_path "$selected_path")"

  existing_session="$(find_session_by_path "$selected_real" || true)"
  if [[ -n "$existing_session" ]]; then
    bump_zoxide_score "$selected_real"
    if [[ -n "${TMUX:-}" ]]; then
      tmux switch-client -t "=$existing_session"
    else
      tmux attach-session -t "=$existing_session"
    fi
    return 0
  fi

  base="$(basename "$selected_real")"
  safe_base="$(sanitize_session_name "$(printf "%s" "$base" | tr -cs 'A-Za-z0-9._-' '_')")"
  session_name="$safe_base"

  # Append a numeric suffix until the name is free.
  while session_exists "$session_name"; do
    session_name="${safe_base}-${suffix}"
    ((suffix++))
  done

  tmux new-session -d -s "$session_name" -c "$selected_real"
  bump_zoxide_score "$selected_real"

  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "=$session_name"
  else
    tmux attach-session -t "=$session_name"
  fi
}

focus_or_launch_tmux_session() {
  # $1 is the packed key: "<name>\x1f<dir>\x1f<cmd>\x1f<keys>" (ASCII unit separator)
  local packed="$1"
  local session_name=""
  local dir=""
  local cmd=""
  local keys=""
  local suffix=2

  session_name="$(printf "%s" "$packed" | cut -d $'\x1f' -f1)"
  dir="$(printf "%s" "$packed" | cut -d $'\x1f' -f2)"
  cmd="$(printf "%s" "$packed" | cut -d $'\x1f' -f3)"
  keys="$(printf "%s" "$packed" | cut -d $'\x1f' -f4)"

  dir="${dir/#\~/$HOME}"

  # Re-use an existing session with the same name.
  if session_exists "$session_name"; then
    if [[ -n "${TMUX:-}" ]]; then
      tmux switch-client -t "=$session_name"
    else
      tmux attach-session -t "=$session_name"
    fi
    return 0
  fi

  local safe_name
  safe_name="$(sanitize_session_name "$(printf "%s" "$session_name" | tr -cs 'A-Za-z0-9._-' '_')")"
  while session_exists "$safe_name"; do
    safe_name="${safe_name}-${suffix}"
    ((suffix++))
  done

  tmux new-session -d -s "$safe_name" ${dir:+-c "$dir"}

  if [[ -n "$cmd" ]]; then
    tmux send-keys -t "${safe_name}:0" "$cmd" Enter
  fi

  if [[ -n "$keys" ]]; then
    sleep 0.3
    tmux send-keys -t "${safe_name}:0" "$keys" ""
  fi

  [[ -n "$dir" && -d "$dir" ]] && bump_zoxide_score "$dir"

  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "=$safe_name"
  else
    tmux attach-session -t "=$safe_name"
  fi
}

focus_or_launch_ssh() {
  local host="$1"
  local safe_host=""
  local session_name=""
  local suffix=2

  safe_host="$(sanitize_session_name "$(printf "%s" "$host" | tr -cs 'A-Za-z0-9._-' '_')")"
  session_name="ssh-${safe_host}"

  if session_exists "$session_name"; then
    if [[ -n "${TMUX:-}" ]]; then
      tmux switch-client -t "=$session_name"
    else
      tmux attach-session -t "=$session_name"
    fi
    return 0
  fi

  # Append a numeric suffix until the name is free.
  while session_exists "$session_name"; do
    session_name="ssh-${safe_host}-${suffix}"
    ((suffix++))
  done

  tmux new-session -d -s "$session_name" "ssh ${host}"

  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "=$session_name"
  else
    tmux attach-session -t "=$session_name"
  fi
}

if [[ "${1:-}" == "--session" ]]; then
  session_file="${tmux_sessions_dir}/${2:-}.tmux-session"
  if [[ ! -f "$session_file" ]]; then
    echo "Session file not found: $session_file"
    exit 1
  fi
  packed="$(parse_tmux_session_file "$session_file" | awk -F'\t' '{print $1}' | sed 's/^session://')"
  focus_or_launch_tmux_session "$packed"
  exit 0
fi

set +e
printf '\033[2J\033[H'
fzf_out="$(
  fzf --ansi --height=20 --reverse \
    --header="Type to filter, enter open, esc quit" \
    --prompt="Create New tmux Session (zoxide + ssh) > " \
    --no-multi \
    --with-nth=2.. \
    --no-sort \
    --tiebreak=index \
    --expect=enter,esc \
    --bind 'enter:accept' \
    --bind 'esc:abort' \
    --bind "start:reload:${script_path} --reload" \
    --bind "change:reload:${script_path} --reload" \
)"
fzf_rc=$?
set -e

if [[ $fzf_rc -ne 0 && -z "${fzf_out:-}" ]]; then
  exit 0
fi

key="$(printf "%s\n" "$fzf_out" | head -n1)"
if [[ "$key" == "esc" ]]; then
  exit 0
fi

sel="$(printf "%s\n" "$fzf_out" | sed -n '2p' || true)"
selected_path=""
if [[ -n "${sel:-}" ]]; then
  selected_path="$(printf "%s" "$sel" | awk -F'\t' '{print $1}')"
fi

if [[ -z "${selected_path:-}" ]]; then
  exit 0
fi

if [[ "$selected_path" == ssh:* ]]; then
  focus_or_launch_ssh "${selected_path#ssh:}"
elif [[ "$selected_path" == session:* ]]; then
  focus_or_launch_tmux_session "${selected_path#session:}"
else
  focus_or_launch_dir "$selected_path"
fi
