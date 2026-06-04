#!/usr/bin/env bash

set -euo pipefail

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

firefox_bookmarks_file="$HOME/dotfiles/bookmarks/firefox-bookmarks.tsv"
bookmarks_files=(
  "$HOME/dotfiles/bookmarks/bookmarks.tsv"
  "$HOME/dotfiles-private/bookmarks/bookmarks.tsv"
  "$firefox_bookmarks_file"
)
fzf_colors_file="$HOME/dotfiles/colorscheme/active/active-fzf-colors.sh"
qat_config="$HOME/dotfiles/kitty/quick-access-terminal-center.conf"
kitty_bin="$(command -v kitty || echo /usr/bin/kitty)"
bookmarks_group="bookmarks"

# Find the active Firefox profile by reading profiles.ini, falling back to the
# first profile dir that actually has a places.sqlite.
firefox_profile_dir() {
  local ini="$HOME/.mozilla/firefox/profiles.ini"
  local base="$HOME/.mozilla/firefox"
  local path is_relative

  if [[ -f "$ini" ]]; then
    # Prefer the [Install*] Default= entry (the profile Firefox launches).
    path="$(awk -F= '/^\[Install/{ininstall=1} ininstall&&/^Default=/{print $2; exit}' "$ini")"
    if [[ -n "$path" && -f "$base/$path/places.sqlite" ]]; then
      printf '%s\n' "$base/$path"
      return 0
    fi
    # Otherwise walk [Profile*] sections and take the first with a places.sqlite.
    while IFS= read -r line; do
      case "$line" in
      Path=*) path="${line#Path=}" ;;
      IsRelative=*) is_relative="${line#IsRelative=}" ;;
      esac
      if [[ -n "${path:-}" ]]; then
        local candidate="$path"
        [[ "${is_relative:-1}" == "1" ]] && candidate="$base/$path"
        if [[ -f "$candidate/places.sqlite" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      fi
    done <"$ini"
  fi

  # Last resort: any profile dir containing places.sqlite.
  for path in "$base"/*/places.sqlite; do
    [[ -f "$path" ]] || continue
    printf '%s\n' "${path%/places.sqlite}"
    return 0
  done

  return 1
}

# Dump Firefox bookmarks to a TSV the picker can read. places.sqlite is locked
# while Firefox runs, so copy it (plus WAL/SHM) to a temp dir and query that.
export_firefox_bookmarks() {
  command -v sqlite3 >/dev/null 2>&1 || return 0

  local profile db tmpdir
  profile="$(firefox_profile_dir)" || return 0
  db="$profile/places.sqlite"
  [[ -f "$db" ]] || return 0

  tmpdir="$(mktemp -d)" || return 0
  cp "$db" "$tmpdir/places.sqlite" 2>/dev/null || {
    rm -rf "$tmpdir"
    return 0
  }
  [[ -f "$db-wal" ]] && cp "$db-wal" "$tmpdir/places.sqlite-wal" 2>/dev/null || true
  [[ -f "$db-shm" ]] && cp "$db-shm" "$tmpdir/places.sqlite-shm" 2>/dev/null || true

  mkdir -p "$(dirname "$firefox_bookmarks_file")"
  local out
  out="$(sqlite3 -separator $'\t' "$tmpdir/places.sqlite" "
    SELECT IFNULL(NULLIF(b.title,''), p.url), p.url
    FROM moz_bookmarks b JOIN moz_places p ON b.fk = p.id
    WHERE b.type = 1 AND p.url LIKE 'http%'
    ORDER BY b.dateAdded DESC;" 2>/dev/null || true)"
  rm -rf "$tmpdir"

  # Only overwrite when we actually got rows, so a transient read failure does
  # not wipe a previously good export.
  [[ -n "$out" ]] && printf '%s\n' "$out" >"$firefox_bookmarks_file"
}

main_kitty_socket() {
  local sock pid args

  # Each QAT creates its own /tmp/kitty-* socket. Use the main kitty process so
  # hide/show commands do not accidentally target another floating terminal.
  for sock in /tmp/kitty-*; do
    [[ -S "$sock" ]] || continue
    pid="${sock##*-}"
    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"

    # On Linux the launcher is usually the python entry point; match either the
    # resolved kitty binary or a bare "kitty" command in the process arguments.
    if [[ "$args" == "$kitty_bin"* || "$args" == kitty* || "$args" == *"/kitty "* ]]; then
      printf '%s\n' "$sock"
      return 0
    fi
  done

  return 1
}

toggle_bookmarks_qat() {
  local sock

  sock="$(main_kitty_socket)" || return 0
  "$kitty_bin" @ --to "unix:${sock}" \
    action launch --type=background kitten quick-access-terminal \
    --config "$qat_config" \
    --instance-group "$bookmarks_group" >/dev/null 2>&1 || true
}

launch_bookmarks_qat() {
  local sock

  sock="$(main_kitty_socket)" || {
    echo "No main kitty socket found."
    exit 1
  }

  "$kitty_bin" @ --to "unix:${sock}" \
    action launch --type=background kitten quick-access-terminal \
    --config "$qat_config" \
    --instance-group "$bookmarks_group" \
    /usr/bin/env bash "$script_path" --pick
}

if [[ "${1:-}" == "--sync-firefox" ]]; then
  export_firefox_bookmarks
  echo "Synced Firefox bookmarks to $firefox_bookmarks_file"
  exit 0
fi

if [[ "${1:-}" == "--pick" ]]; then
  # Refresh the Firefox export before showing the picker so it stays in sync.
  export_firefox_bookmarks

  bookmark_reload_cmd='query={q}; if [[ ${#query} -ge 3 ]]; then for bookmarks_file in'
  fzf_args=(
    --height=100%
    --reverse
    --delimiter=$'\t'
    --with-nth=1
    --header="Type at least 3 characters to search bookmarks"
    --prompt="Open bookmark > "
  )
  has_bookmarks=false

  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is not installed."
    read -r -p "Press enter to close. "
    exit 1
  fi

  for bookmarks_file in "${bookmarks_files[@]}"; do
    if [[ -s "$bookmarks_file" ]]; then
      has_bookmarks=true
      break
    fi
  done

  if [[ "$has_bookmarks" == false ]]; then
    echo "No bookmarks found in:"
    printf '  %s\n' "${bookmarks_files[@]}"
    read -r -p "Press enter to close. "
    exit 1
  fi

  if [[ -f "$fzf_colors_file" ]]; then
    # shellcheck disable=SC1090
    source "$fzf_colors_file"
  fi

  for bookmarks_file in "${bookmarks_files[@]}"; do
    printf -v quoted_bookmarks_file '%q' "$bookmarks_file"
    bookmark_reload_cmd+=" $quoted_bookmarks_file"
  done
  bookmark_reload_cmd+='; do [[ -s "$bookmarks_file" ]] && cat "$bookmarks_file"; done; fi'
  fzf_args+=(--bind "change:reload($bookmark_reload_cmd)")

  if [[ -n "${linkarzu_fzf_colors:-}" ]]; then
    fzf_args+=(--color="$linkarzu_fzf_colors")
  fi

  while true; do
    # Keep this process alive after every action. When the QAT process stays
    # alive, kitty only toggles visibility instead of cold-starting a new panel.
    if ! selected=$(: | fzf "${fzf_args[@]}"); then
      # Esc makes fzf exit non-zero. Treat it as "hide and rearm" so the next
      # keypress shows an already-running picker instead of starting from cold.
      toggle_bookmarks_qat
      continue
    fi

    IFS=$'\t' read -r _name url <<<"$selected"

    if [[ -z "${url:-}" ]]; then
      echo "Invalid bookmark: $selected"
      read -r -p "Press enter to continue. "
      toggle_bookmarks_qat
      continue
    fi

    toggle_bookmarks_qat
    xdg-open "$url" >/dev/null 2>&1 &
    disown
  done
fi

launch_bookmarks_qat
