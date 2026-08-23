#!/usr/bin/env bash
set -u

WATCH_DIR="${WATCH_DIR:-$HOME/Downloads}"

is_temporary_download() {
  case "$1" in
  *.part | *.crdownload | *.tmp | *.temp) return 0 ;;
  *) return 1 ;;
  esac
}

image_mime_type() {
  local ext="${1##*.}"

  case "${ext,,}" in
  avif) printf '%s\n' 'image/avif' ;;
  bmp) printf '%s\n' 'image/bmp' ;;
  gif) printf '%s\n' 'image/gif' ;;
  jpeg | jpg) printf '%s\n' 'image/jpeg' ;;
  png) printf '%s\n' 'image/png' ;;
  tif | tiff) printf '%s\n' 'image/tiff' ;;
  webp) printf '%s\n' 'image/webp' ;;
  esac
}

path_to_uri() {
  python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).absolute().as_uri())' "$1"
}

file_is_open() {
  local path="$1"

  if command -v lsof >/dev/null 2>&1; then
    lsof -t -- "$path" >/dev/null 2>&1
  else
    fuser -- "$path" >/dev/null 2>&1
  fi
}

wait_for_stable_file() {
  local path="$1"
  local previous_size current_size

  # A single short size check isn't enough: yt-dlp flushes progress to disk
  # between percentage updates, so the file can look momentarily stable
  # while still downloading. Require the size to hold steady over a longer
  # window and confirm no process still has the file open for writing.
  previous_size="$(stat -c %s -- "$path" 2>/dev/null)" || return 1
  sleep 1
  current_size="$(stat -c %s -- "$path" 2>/dev/null)" || return 1
  [[ "$previous_size" == "$current_size" ]] || return 1

  ! file_is_open "$path"
}

copy_file_to_clipboard() {
  local path="$1"
  local uri mime

  uri="$(path_to_uri "$path")" || return 1
  mime="$(image_mime_type "$path")"

  if [[ -n "$mime" ]] && command -v copyq >/dev/null 2>&1; then
    copyq --start-server copy \
      "$mime" - \
      text/plain "$path" \
      text/uri-list "$uri"$'\r\n' <"$path" && return 0
  fi

  if [[ -n "$mime" ]]; then
    wl-copy --type "$mime" <"$path"
  else
    printf '%s\r\n' "$uri" | wl-copy --type text/uri-list
  fi
}

declare -A last_copied_size

inotifywait -m -e moved_to -e close_write --format '%w%f' "$WATCH_DIR" |
  while IFS= read -r filepath; do
    [[ -f "$filepath" ]] || continue
    is_temporary_download "$filepath" && continue
    wait_for_stable_file "$filepath" || continue

    size="$(stat -c %s -- "$filepath" 2>/dev/null)" || continue
    [[ "${last_copied_size[$filepath]:-}" == "$size" ]] && continue

    copy_file_to_clipboard "$filepath" && last_copied_size[$filepath]="$size"
  done
