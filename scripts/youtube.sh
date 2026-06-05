#!/usr/bin/env bash

set -euo pipefail

script_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Fuzzy-find YouTube videos by channel or playlist and open the pick in the
# browser. Mirrors the look/feel of bookmarks.sh (same fzf colors).
#
# Usage:
#   youtube.sh <channel>            # @handle, channel URL, or channel name
#   youtube.sh -s [query]           # live YouTube search (videos + channels); a
#                                   # video opens, a channel drills into its videos
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
# Workspace the opened video should land on. Intentionally differs from
# bookmarks.sh (which uses 2): videos go to workspace 4.
firefox_workspace="4"

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

  # Image area: top of the preview pane. FZF_PREVIEW_* are set by fzf.
  cols="${FZF_PREVIEW_COLUMNS:-40}"
  max_lines="${FZF_PREVIEW_LINES:-20}"

  # Work out how many text rows the image occupies, so we pad by exactly that
  # and the title/duration land right under it (no mid-pane gap). icat fits the
  # image into the --place box preserving aspect, so if we make img_lines match
  # the image's real shape at the pane width, the image fills exactly that many
  # rows and our pad lands on the next line.
  #
  #   image px aspect      = img_w/img_h          (e.g. 480/360 = 4:3)
  #   cell aspect (h/w)    = YOUTUBE_FZF_CELL_ASPECT, default 2.1 (×10 = 21)
  #   rows = cols * (img_h/img_w) / cell_aspect
  img_w=480 img_h=360 # YouTube thumbnail default (4:3); refined below if possible
  if command -v identify >/dev/null 2>&1; then
    read -r img_w img_h < <(identify -format '%w %h' "$thumb" 2>/dev/null) || {
      img_w=480 img_h=360
    }
    [[ "$img_w" =~ ^[0-9]+$ && "$img_h" =~ ^[0-9]+$ && "$img_w" -gt 0 ]] || {
      img_w=480 img_h=360
    }
  fi
  cell_aspect_x10="${YOUTUBE_FZF_CELL_ASPECT:-21}" # cell height/width × 10
  ((cell_aspect_x10 > 0)) || cell_aspect_x10=21
  # Box width starts at the full pane width; height follows from the image
  # aspect so the --place box matches the image and icat fills it WITHOUT
  # overflowing (an overflow would draw over the text below). If that height is
  # taller than ~60% of the pane, shrink the WIDTH too so the box stays the same
  # shape but fits — keeping room for the title/duration underneath.
  img_cols=$cols
  img_lines=$(((img_cols * img_h * 10) / (img_w * cell_aspect_x10)))
  cap=$((max_lines * 6 / 10))
  ((cap < 1)) && cap=1
  if ((img_lines > cap)); then
    img_lines=$cap
    # width that preserves the image aspect at this height
    img_cols=$(((img_lines * img_w * cell_aspect_x10) / (img_h * 10)))
    ((img_cols < 1)) && img_cols=1
    ((img_cols > cols)) && img_cols=$cols
  fi
  ((img_lines < 1)) && img_lines=1

  drew_image=false
  if [[ -s "$thumb" ]]; then
    # Prefer kitty's graphics protocol; fall back to chafa (unicode blocks),
    # which works in any preview pane without graphics support. Set
    # YOUTUBE_FZF_IMG=chafa to force the fallback.
    if [[ "${YOUTUBE_FZF_IMG:-}" != "chafa" ]] && command -v kitten >/dev/null 2>&1; then
      kitten icat --clear --transfer-mode=memory --unicode-placeholder \
        --stdin=no --scale-up --place="${img_cols}x${img_lines}@0x0" "$thumb" 2>/dev/null &&
        drew_image=true
    fi
    if [[ "$drew_image" == false ]] && command -v chafa >/dev/null 2>&1; then
      chafa --clear --format=symbols --size="${img_cols}x${img_lines}" "$thumb" 2>/dev/null &&
        drew_image=true
    fi
  fi
  # Move cursor to just below the image before printing text. icat with
  # --place leaves the cursor at the placement origin, so we step down exactly
  # img_lines rows; under tmux the cursor is unreliable, so this explicit pad is
  # what guarantees the text sits directly under the image.
  if [[ "$drew_image" == true ]]; then
    printf '\n%.0s' $(seq 1 "$img_lines")
  fi

  # Show duration first (one line, no blank gap) so it stays visible even when
  # the title wraps and the image has eaten half the pane height.
  [[ -n "$duration" && "$duration" != "NA" ]] && printf 'Duration: %s\n' "$duration"
  [[ -n "$title" ]] && printf '%s\n' "$title"
  exit 0
fi

# Live-search mode: query YouTube and print one TSV row per result for fzf to
# display and filter. Called repeatedly by fzf's `change:reload` as the user
# types, so it must be self-contained and fast (flat search, no per-item fetch).
#
# Called as: --ytsearch <mode> <query>, where mode is "videos" or "channels"
# (toggled in the picker with Ctrl-T). The two are separate searches, not merged,
# so each mode shows a clean single list:
#   videos   — plain `ytsearch:` = YouTube's "All" tab, in relevance order. Mostly
#              videos; reads like the real YouTube search bar.
#   channels — the Channels-tab filter (results?search_query=…&sp=EgIQAg==), which
#              reliably returns real channels with @handles. A plain ytsearch only
#              surfaces a channel for an exact name, so this mode is how you find
#              "@linkarzu" by typing partial text.
#
# Output columns (tab-separated). Columns 1–5 are machine-readable (the caller
# parses them after a pick); column 6 is the human-readable line fzf shows and
# filters (--with-nth=6):
#   1 kind     channel|video — drives the action on Enter
#   2 id       channel_id (UC…) for channels, video id for videos
#   3 handle   @handle for channels (may be empty), empty for videos
#   4 title    channel name or video title
#   5 dur      duration_string for videos, empty for channels
#   6 display  "◉  <channel>   <handle>" or "▶  <title>   <dur>"
if [[ "${1:-}" == "--ytsearch" ]]; then
  tab=$'\t'
  search_mode="${2:-videos}"
  query="${3:-}"
  [[ -n "$query" ]] || exit 0

  print_tmpl="%(ie_key)s${tab}%(id)s${tab}%(channel)s${tab}%(uploader_id)s${tab}%(title)s${tab}%(duration_string)s"
  # awk turns each yt-dlp row into our 6-column TSV: YoutubeTab rows render as
  # channels (◉, drill-down), Youtube rows as videos (▶). Order is preserved.
  render='
    BEGIN { FS=OFS="\t" }
    {
      ie=$1; id=$2; channel=$3; handle=$4; title=$5; dur=$6
      if (handle=="NA") handle=""
      if (dur=="NA")    dur=""
      if (ie=="YoutubeTab" && id!="" && id!="NA") {
        disp="\033[36m◉\033[0m  " channel
        if (handle!="") disp=disp "  \033[2m" handle "\033[0m"
        print "channel", id, handle, channel, "", disp
      } else if (ie=="Youtube" && id!="" && id!="NA") {
        disp="▶  " title
        if (dur!="") disp=disp "  \033[2m" dur "\033[0m"
        print "video", id, "", title, dur, disp
      }
    }'

  if [[ "$search_mode" == "channels" ]]; then
    # Channels-tab filter needs the query URL-encoded.
    enc="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$query" 2>/dev/null)"
    [[ -n "$enc" ]] || exit 0
    yt-dlp --flat-playlist --no-warnings --playlist-end 20 --print "$print_tmpl" \
      "https://www.youtube.com/results?search_query=${enc}&sp=EgIQAg%3D%3D" 2>/dev/null |
      awk "$render"
  else
    yt-dlp --flat-playlist --no-warnings --playlist-end 30 --print "$print_tmpl" \
      "ytsearch30:$query" 2>/dev/null |
      awk "$render"
  fi
  exit 0
fi

usage() {
  sed -n '7,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

tab=$'\t'

source_fzf_colors() {
  if [[ -f "$fzf_colors_file" ]]; then
    # shellcheck disable=SC1090
    source "$fzf_colors_file"
  fi
}

# Force the keyboard to English so the fzf query types as latin even when the
# active layout is Russian. Index 0 is "us" in hyprland.conf's kb_layout (us,ru).
# Best-effort: silently no-op outside Hyprland.
switch_to_english() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl switchxkblayout all 0 >/dev/null 2>&1 || true
}

# Open a video in the browser, then bring Firefox to workspace 4 and focus it.
#
# Always opens a NEW tab (no brotab tab-reuse): a video search almost always
# wants a fresh watch. setsid detaches xdg-open so it survives this script
# exiting — otherwise the QAT panel closing the instant we exit would kill it
# before the browser picks up the URL.
#
# Unlike bookmarks.sh (which only moves Firefox on a cold start), this ALWAYS
# moves Firefox to workspace 4 and focuses it, so the video lands there every
# time regardless of where Firefox was. Polls a few times for the window in case
# Firefox is starting cold. Best-effort: no-ops outside Hyprland.
open_video() {
  setsid -f xdg-open "https://www.youtube.com/watch?v=$1" >/dev/null 2>&1

  command -v hyprctl >/dev/null 2>&1 || return 0
  # The QAT panel hides asynchronously; settle briefly so Hyprland doesn't
  # re-grab focus after us.
  sleep 0.15
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if hyprctl clients -j 2>/dev/null | grep -q '"class": *"firefox"'; then
      hyprctl dispatch movetoworkspace "${firefox_workspace},class:firefox" >/dev/null 2>&1 || true
      hyprctl dispatch focuswindow class:firefox >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.25
  done
  return 0
}

# Live YouTube search, like the site's search bar: the user types in fzf and
# every keystroke re-queries YouTube (change:reload calls us back in
# --ytsearch mode). Two modes, toggled with Ctrl-T: videos (▶, the default) and
# channels (◉). Enter on a video opens it; Enter on a channel sets $target to its
# @handle and returns so the caller falls through to that channel's video listing.
#
# Returns 0 with $target set to an @handle (caller continues in channel mode),
# or exits the whole script directly when a video was opened / nothing picked.
search_live() {
  local query="$1" sel kind id handle
  source_fzf_colors
  # Flip to English so the typed query is latin even from a Russian layout. When
  # launched via the QAT panel this only fires on a cold start (the panel toggle
  # reuses the process), so youtube-qat.sh also switches on every show.
  switch_to_english

  # Mode (videos|channels) lives in a temp file so fzf's static reload binds can
  # read the current value; Ctrl-T rewrites it and reloads. Start in videos mode.
  local mode_file
  mode_file="$(mktemp -t yt-search-mode.XXXXXX)"
  printf 'videos' >"$mode_file"
  # Clean up the state file when search_live returns or the script exits.
  trap 'rm -f "$mode_file"' RETURN

  # The reload binds call --ytsearch with the mode read from $mode_file, so a
  # Ctrl-T flip takes effect on the very next reload without re-launching fzf.
  local search_cmd="\"$script_self\" --ytsearch \"\$(cat '$mode_file')\" {q}"

  # Seed the list with the initial query; change:reload refreshes it as typed.
  # --preview only makes sense for videos (col 2 = video id); for channels the
  # id is a UC… channel id and open_video isn't used, so the preview just shows
  # nothing useful — that's fine.
  #
  # Ctrl-T toggles videos<->channels: rewrite the mode file, update the prompt to
  # show the active mode, then re-run the search in the new mode for the same query.
  local toggle="transform:
    if [[ \"\$(cat '$mode_file')\" == videos ]]; then
      printf channels >'$mode_file'
      echo \"change-prompt(Search channels > )+reload($search_cmd)+first\"
    else
      printf videos >'$mode_file'
      echo \"change-prompt(Search YouTube > )+reload($search_cmd)+first\"
    fi"

  local fzf_args=(
    --height=100%
    --reverse
    --ansi
    --delimiter=$'\t'
    --with-nth=6
    --query="$query"
    --disabled
    --prompt="Search YouTube > "
    --header="Enter: ▶ video → open · ◉ channel → its videos · Ctrl-T: videos/channels · Esc: cancel"
    --bind "change:reload(sleep 0.3; $search_cmd)+first"
    --bind "start:reload($search_cmd)"
    --bind "ctrl-t:$toggle"
    --preview "\"$script_self\" --preview {2} {4} {5}"
    --preview-window "right,55%,wrap"
  )
  [[ -n "${linkarzu_fzf_colors:-}" ]] && fzf_args+=(--color="$linkarzu_fzf_colors")

  # --ytsearch feeds rows on each keystroke (start/change reload). Column 6 is
  # the prefixed ◉/▶ line fzf shows; columns 1–3 carry kind/id/handle for the
  # action below. fzf gets nothing on its own stdin (rows come from reload).
  sel="$(fzf "${fzf_args[@]}" </dev/null)" || exit 0
  [[ -n "$sel" ]] || exit 0

  IFS="$tab" read -r kind id handle _ <<<"$sel"
  case "$kind" in
  video)
    open_video "$id"
    exit 0
    ;;
  channel)
    if [[ "$handle" == @* ]]; then
      target="$handle"
    else
      # Channel result without a handle (rare): fall back to the channel id,
      # which yt-dlp can enumerate via the /channel/<id>/videos URL.
      target="https://www.youtube.com/channel/$id/videos"
    fi
    return 0
    ;;
  *)
    exit 0
    ;;
  esac
}

# Search mode: live YouTube search -> open video, or fall through to a channel.
if [[ "$mode" == "search" ]]; then
  query="${1:-}"
  search_live "$query"
  # Returns only when a channel was picked; $target now holds it.
  [[ -n "${target:-}" ]] || exit 0
  refresh=true # always show that channel's freshest videos right after picking
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

open_video "$id"
