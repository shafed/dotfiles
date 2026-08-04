#!/usr/bin/env bash

# Filename: ~/dotfiles/kitty/scripts/kitty-zoxide-session.sh
# Select a zoxide entry and switch to an existing kitty session,
# or create it if it doesn't exist.
#
# Also supports:
#   - Named sessions from *.kitty-session files in ~/dotfiles/kitty/sessions/.
#     These are shown with a "s-" prefix.
#   - SSH host entries from ~/.ssh/config (and Include files).
#     SSH entries are shown with a "ssh-" prefix.
#
# Requires: kitty with allow_remote_control yes + listen_on unix:/tmp/kitty-{kitty_pid}
# Shown as a kitty quick-access panel (QAT); inside it $KITTY_LISTEN_ON points
# at the panel instance, so the script is re-pointed at the main kitty socket
# (--qat) before any `kitten @` call. Plain invocation = QAT launcher.

set -euo pipefail

script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
kitty_sessions_dir="$HOME/dotfiles/kitty/sessions"
transient_sessions_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kitty-sessions"
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
require_cmd jq "Install: sudo pacman -S jq"
require_cmd zoxide "Install: sudo pacman -S zoxide"

dotfiles_dir="$HOME/dotfiles"
# Shared QAT helpers (main_kitty_socket, launch_qat) + gruvbox fzf colors.
# shellcheck source=../../scripts/lib.sh
source "$dotfiles_dir/scripts/lib.sh"
qat_group="zoxide-session"

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

# Gruvbox Material colors from ../current-theme.conf.
base_color=$'\033[1;38;2;169;182;101m' # color2: #a9b665
reset_color=$'\033[0m'

bump_zoxide_score() {
  local path="$1"
  zoxide add -- "$path" >/dev/null 2>&1 || true
}

# Check if a session with the given name is currently open in kitty.
session_exists() {
  local name="$1"
  kitten @ ls 2>/dev/null | jq -e --arg name "$name" '
    any(.[]?.tabs[]?.windows[]?; .session_name == $name)
  ' >/dev/null
}

# Find an open kitty session whose working directory matches the target path.
# Prints the session name if found.
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
    kitten @ ls 2>/dev/null | jq -r '
      .[]?.tabs[]?.windows[]?
      | select(.session_name != null and .session_name != "")
      | [(.session_name|tostring), (.env.PWD // .cwd // "")]
      | @tsv
    '
  )

  return 1
}

print_menu_lines() {
  # Named kitty-session entries come first so they're easy to spot / filter.
  print_kitty_session_menu_lines

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

print_kitty_session_menu_lines() {
  [[ -d "$kitty_sessions_dir" ]] || return 0
  local f=""
  local name=""
  local label=""
  for f in "$kitty_sessions_dir"/*.kitty-session; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .kitty-session)"
    label="s-${name}"
    printf "named:%s\t%b%s%b  %s\n" \
      "$name" \
      "${base_color}" "$label" "${reset_color}" \
      "$f"
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

# Switch to (or create) a named kitty session file from ~/dotfiles/kitty/sessions/.
focus_or_launch_named_session() {
  local name="$1"
  local session_file="${kitty_sessions_dir}/${name}.kitty-session"

  if [[ ! -f "$session_file" ]]; then
    echo "Session file not found: $session_file"
    exit 1
  fi

  # goto_session re-focuses if already open, or creates it if not.
  kitten @ action goto_session "$session_file"
}

focus_or_launch_dir() {
  local selected_path="$1"
  local selected_real=""
  local base=""
  local safe_base=""
  local session_name=""
  local existing_session=""
  local session_file=""
  local suffix=2

  if [[ ! -d "$selected_path" ]]; then
    echo "Directory not found: $selected_path"
    exit 1
  fi

  selected_real="$(normalize_path "$selected_path")"

  # If a session already has this path open, switch to it via its transient file.
  existing_session="$(find_session_by_path "$selected_real" || true)"
  if [[ -n "$existing_session" ]]; then
    bump_zoxide_score "$selected_real"
    # The transient file for this session (if any) lives in the cache dir.
    local transient_file="${transient_sessions_dir}/${existing_session}.kitty-session"
    if [[ -f "$transient_file" ]]; then
      kitten @ action goto_session "$transient_file"
    else
      kitten @ action goto_session "$existing_session"
    fi
    return 0
  fi

  base="$(basename "$selected_real")"
  safe_base="$(printf "%s" "$base" | tr -cs 'A-Za-z0-9._-' '_')"
  session_name="z-${safe_base}"

  # Append a numeric suffix until the name is free.
  while session_exists "$session_name"; do
    session_name="z-${safe_base}-${suffix}"
    ((suffix++))
  done

  mkdir -p "$transient_sessions_dir"
  session_file="${transient_sessions_dir}/${session_name}.kitty-session"

  cat >"$session_file" <<EOF
layout tall
cd ${selected_real}
launch --title "${base}"
focus
focus_os_window
EOF

  kitten @ action goto_session "$session_file"
  bump_zoxide_score "$selected_real"
}

focus_or_launch_ssh() {
  local host="$1"
  local safe_host=""
  local session_name=""
  local session_file=""
  local suffix=2

  safe_host="$(printf "%s" "$host" | tr -cs 'A-Za-z0-9._-' '_')"
  session_name="ssh-${safe_host}"

  # If already open, re-focus via the existing transient file.
  if session_exists "$session_name"; then
    local transient_file="${transient_sessions_dir}/${session_name}.kitty-session"
    if [[ -f "$transient_file" ]]; then
      kitten @ action goto_session "$transient_file"
      return 0
    fi
  fi

  # Append a numeric suffix until the name is free.
  while session_exists "$session_name"; do
    session_name="ssh-${safe_host}-${suffix}"
    ((suffix++))
  done

  mkdir -p "$transient_sessions_dir"
  session_file="${transient_sessions_dir}/${session_name}.kitty-session"

  cat >"$session_file" <<EOF
layout tall
launch --title "ssh-${host}" ssh ${host}
focus
focus_os_window
EOF

  kitten @ action goto_session "$session_file"
}

if [[ "${1:-}" == "--named" ]]; then
  focus_or_launch_named_session "${2:-}"
  exit 0
fi

# QAT dispatch: `--qat` runs the picker inside the quick-access panel, talking
# to the MAIN kitty's socket (inside the panel $KITTY_LISTEN_ON points at the
# panel's own instance, where goto_session would act on the wrong kitty).
# Plain invocation (kanata apps+e) is the launcher: show the picker as a panel.
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

set +e
printf '\033[2J\033[H'
fzf_out="$(
  fzf --ansi --height=20 --reverse \
    --header="Type to filter, enter open, esc quit" \
    --prompt="Create New Kitty Session (named + zoxide + ssh) > " \
    --no-multi \
    --with-nth=2.. \
    --no-sort \
    --tiebreak=index \
    --expect=enter,esc \
    --bind 'enter:accept' \
    --bind 'esc:abort' \
    --bind "start:reload:${script_path} --reload" \
    --bind "change:reload:${script_path} --reload"
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

if [[ "$selected_path" == named:* ]]; then
  focus_or_launch_named_session "${selected_path#named:}"
elif [[ "$selected_path" == ssh:* ]]; then
  focus_or_launch_ssh "${selected_path#ssh:}"
else
  focus_or_launch_dir "$selected_path"
fi
