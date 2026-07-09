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
  python -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).absolute().as_uri())' "$1"
}

wait_for_stable_file() {
  local path="$1"
  local previous_size current_size

  previous_size="$(stat -c %s -- "$path" 2>/dev/null)" || return 1
  sleep 0.2
  current_size="$(stat -c %s -- "$path" 2>/dev/null)" || return 1

  [[ "$previous_size" == "$current_size" ]]
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

inotifywait -m -e moved_to -e close_write --format '%w%f' "$WATCH_DIR" |
  while IFS= read -r filepath; do
    [[ -f "$filepath" ]] || continue
    is_temporary_download "$filepath" && continue
    wait_for_stable_file "$filepath" || continue

    copy_file_to_clipboard "$filepath"
  done
