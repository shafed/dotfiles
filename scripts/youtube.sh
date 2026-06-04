#!/usr/bin/env bash

set -euo pipefail

script_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Fuzzy-find YouTube videos by channel or playlist and open the pick in the
# browser. Mirrors the look/feel of bookmarks.sh (same fzf colors).
#
# Usage:
#   youtube.sh <channel>            # @handle, channel URL, or channel name
#   youtube.sh -s [query]           # search channels by name via fzf, then videos
#   youtube.sh -p <playlist>        # playlist URL or ID (public only)
#   youtube.sh -r <channel>         # refresh cache for that channel/playlist
#   youtube.sh -n <count> <channel> # limit how many recent videos to list
#
# Notes:
#   - Uses yt-dlp, so it sees PUBLIC data only: channel uploads and public /
#     unlisted playlists. It can NOT see your private playlists, subscriptions,
#     or "Watch later" — that needs the YouTube Data API + OAuth.

fzf_colors_file="$HOME/dotfiles/colorscheme/active/active-fzf-colors.sh"
cache_dir="$HOME/.cache/youtube-fzf"
thumb_dir="$cache_dir/thumbs"
limit=40
refresh=false
mode="channel"

# Render the fzf preview for a single video: thumbnail (kitty graphics) on top,
# then title + duration. Everything comes from the id and the already-built TSV
# row passed as args, so the preview makes NO network request on hover — only a
# one-time thumbnail download (cached). Fast, and instant on re-hover.
# Called as a subprocess by fzf, so it must not depend on the rest of the script.
if [[ "${1:-}" == "--preview" ]]; then
  vid="${2:-}"
  title="${3:-}"
  duration="${4:-}"
  [[ -n "$vid" ]] || exit 0
  mkdir -p "$thumb_dir"

  thumb="$thumb_dir/$vid.jpg"
  if [[ ! -s "$thumb" ]]; then
    # hqdefault always exists; fall back order keeps it fast and reliable.
    for v in hqdefault mqdefault default; do
      if curl -fsS -o "$thumb" "https://i.ytimg.com/vi/$vid/$v.jpg" 2>/dev/null && [[ -s "$thumb" ]]; then
        break
      fi
    done
  fi

  # Image area: top portion of the preview pane. FZF_PREVIEW_* are set by fzf.
  cols="${FZF_PREVIEW_COLUMNS:-40}"
  img_lines=$((${FZF_PREVIEW_LINES:-20} / 2))
  drew_image=false
  if [[ -s "$thumb" ]]; then
    # Prefer kitty's graphics protocol; fall back to chafa (unicode blocks),
    # which works in any preview pane without graphics support. Set
    # YOUTUBE_FZF_IMG=chafa to force the fallback.
    if [[ "${YOUTUBE_FZF_IMG:-}" != "chafa" ]] && command -v kitten >/dev/null 2>&1; then
      kitten icat --clear --transfer-mode=memory --unicode-placeholder \
        --stdin=no --scale-up --place="${cols}x${img_lines}@0x0" "$thumb" 2>/dev/null &&
        drew_image=true
    fi
    if [[ "$drew_image" == false ]] && command -v chafa >/dev/null 2>&1; then
      chafa --clear --format=symbols --size="${cols}x${img_lines}" "$thumb" 2>/dev/null &&
        drew_image=true
    fi
  fi
  # Move cursor below the image area before printing text (icat leaves it at top).
  if [[ "$drew_image" == true ]]; then
    printf '\n%.0s' $(seq 1 "$img_lines")
  fi

  # Show duration first (one line, no blank gap) so it stays visible even when
  # the title wraps and the image has eaten half the pane height.
  [[ -n "$duration" && "$duration" != "NA" ]] && printf 'Duration: %s\n' "$duration"
  [[ -n "$title" ]] && printf '%s\n' "$title"
  exit 0
fi

usage() {
  sed -n '7,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

for tool in yt-dlp fzf; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is not installed." >&2
    exit 1
  fi
done

while getopts ":spn:rh" opt; do
  case "$opt" in
  s) mode="search" ;;
  p) mode="playlist" ;;
  n) limit="$OPTARG" ;;
  r) refresh=true ;;
  h) usage 0 ;;
  \?)
    echo "Unknown option: -$OPTARG" >&2
    usage 1
    ;;
  :)
    echo "Option -$OPTARG needs an argument." >&2
    usage 1
    ;;
  esac
done
shift $((OPTIND - 1))

source_fzf_colors() {
  if [[ -f "$fzf_colors_file" ]]; then
    # shellcheck disable=SC1090
    source "$fzf_colors_file"
  fi
}

# Search channels by name and let the user pick one; prints its @handle.
# Builds a channel list by sampling search results and de-duplicating by handle.
search_channel_handle() {
  local query="$1" results sel
  echo "Searching channels for: $query" >&2
  # channel name \t @handle; keep only rows with a real @handle, de-dup by it.
  results="$(yt-dlp --flat-playlist --no-warnings --playlist-end 20 \
    --print "%(channel)s${tab}%(uploader_id)s" \
    "ytsearch20:$query" 2>/dev/null |
    awk -F'\t' '$2 ~ /^@/ && !seen[$2]++')"
  [[ -n "$results" ]] || {
    echo "No channels found for: $query" >&2
    return 1
  }

  source_fzf_colors
  # Show "Channel name  @handle" so the handle is visible while picking.
  local fzf_args=(--height=100% --reverse --delimiter=$'\t' --with-nth=1,2
    --prompt="Channel > " --header="Pick a channel for: $query")
  [[ -n "${linkarzu_fzf_colors:-}" ]] && fzf_args+=(--color="$linkarzu_fzf_colors")

  sel="$(printf '%s\n' "$results" | fzf "${fzf_args[@]}")" || return 1
  printf '%s' "${sel#*$tab}"
}

tab=$'\t'

# Search mode: query -> pick channel -> fall through to that channel's videos.
if [[ "$mode" == "search" ]]; then
  query="${1:-}"
  if [[ -z "$query" ]]; then
    read -r -p "Search YouTube channel: " query
  fi
  [[ -n "$query" ]] || exit 0
  target="$(search_channel_handle "$query")" || exit 0
  [[ -n "$target" ]] || exit 0
  mode="channel"
else
  target="${1:-}"
fi

if [[ -z "$target" ]]; then
  usage 1
fi

# Build the source URL yt-dlp should enumerate.
if [[ "$mode" == "playlist" ]]; then
  case "$target" in
  http*) source_url="$target" ;;
  *) source_url="https://www.youtube.com/playlist?list=$target" ;;
  esac
  cache_key="pl-$(printf '%s' "$target" | tr -c 'A-Za-z0-9' '_')"
else
  case "$target" in
  http*) source_url="$target" ;;
  @*) source_url="https://www.youtube.com/$target/videos" ;;
  *) source_url="https://www.youtube.com/@$target/videos" ;;
  esac
  cache_key="ch-$(printf '%s' "$target" | tr -c 'A-Za-z0-9' '_')"
fi

mkdir -p "$cache_dir"
cache_file="$cache_dir/$cache_key.tsv"

# (Re)build the cache when missing, stale (>6h), or forced with -r.
needs_fetch=true
if [[ "$refresh" == false && -s "$cache_file" ]]; then
  if [[ -z "$(find "$cache_file" -mmin +360 2>/dev/null)" ]]; then
    needs_fetch=false
  fi
fi

if [[ "$needs_fetch" == true ]]; then
  echo "Fetching from YouTube..." >&2
  # Use a literal tab in the template; yt-dlp does not interpret "\t".
  # duration_string is the only useful metadata --flat-playlist returns fast
  # (view_count/upload_date come back as NA without per-video requests).
  if ! yt-dlp --flat-playlist --no-warnings \
    --playlist-end "$limit" \
    --print "%(id)s${tab}%(title)s${tab}%(duration_string)s" \
    "$source_url" >"$cache_file.tmp" 2>/dev/null; then
    rm -f "$cache_file.tmp"
    echo "Could not fetch videos for: $target" >&2
    exit 1
  fi
  # Only replace a good cache if we actually got rows.
  if [[ -s "$cache_file.tmp" ]]; then
    mv "$cache_file.tmp" "$cache_file"
  else
    rm -f "$cache_file.tmp"
    echo "No videos found for: $target" >&2
    exit 1
  fi
fi

if [[ ! -s "$cache_file" ]]; then
  echo "No videos found for: $target" >&2
  exit 1
fi

fzf_args=(
  --height=100%
  --reverse
  --delimiter=$'\t'
  --with-nth=2
  --prompt="Open video > "
  --header="$target — Enter to open in browser, Esc to cancel"
  --preview "$script_self --preview {1} {2} {3}"
  --preview-window "right,55%,wrap"
)

source_fzf_colors
if [[ -n "${linkarzu_fzf_colors:-}" ]]; then
  fzf_args+=(--color="$linkarzu_fzf_colors")
fi

selected="$(fzf "${fzf_args[@]}" <"$cache_file")" || exit 0

IFS=$'\t' read -r id _title <<<"$selected"
if [[ -z "${id:-}" ]]; then
  echo "Invalid selection: $selected" >&2
  exit 1
fi

url="https://www.youtube.com/watch?v=$id"

# Detach the browser into its own session so it survives this QAT panel closing
# the instant the script exits (otherwise xdg-open is killed before the browser
# picks up the URL). setsid avoids needing a pause.
setsid -f xdg-open "$url" >/dev/null 2>&1
