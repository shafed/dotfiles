#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_self="$script_dir/$(basename "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

# Fuzzy-find YouTube videos by channel or playlist and open the pick in the
# browser. Mirrors the look/feel of bookmarks.sh (same fzf colors).
#
# Usage:
#   youtube.sh <channel>            # @handle, channel URL, or channel name
#                                   # (Ctrl-S in the list toggles videos/streams)
#   youtube.sh -s [query]           # live YouTube search (videos + channels); a
#                                   # video opens, a channel drills into its videos
#   youtube.sh -p <playlist>        # playlist URL or ID (public only)
#   youtube.sh -H                   # your YouTube watch history (logged-in)
#   youtube.sh -r <channel>         # refresh cache for that channel/playlist
#   youtube.sh -n <count> <channel> # limit how many recent videos to list
#
# Notes:
#   - Uses yt-dlp. For channels/playlists/search it sees PUBLIC data only:
#     channel uploads and public / unlisted playlists.
#   - Watch history (-H) reads your logged-in session from the browser's
#     cookies (yt-dlp --cookies-from-browser), so it needs you signed into
#     YouTube in that browser. No OAuth required.

cache_dir="$HOME/.cache/youtube-fzf"
thumb_dir="$cache_dir/thumbs"
limit=40
refresh=false
mode="channel"
# Browser whose cookies yt-dlp reads for logged-in data (watch history).
cookies_browser="firefox"
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
  channel="${5:-}"
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
  # Cap the image to ~60% of the pane height so the title/duration always fit
  # beneath it.
  cap=$((max_lines * 6 / 10))
  ((cap < 1)) && cap=1

  drew_image=false
  if [[ -s "$thumb" ]]; then
    # Prefer kitty's graphics protocol; fall back to chafa (unicode blocks),
    # which works in any preview pane without graphics support. Set
    # YOUTUBE_FZF_IMG=chafa to force the fallback.
    #
    # The key for correct text placement: do NOT use --place. With --place the
    # cursor is restored to the image's top-left, forcing us to guess the
    # rendered height and pad by hand — and that guess (cell aspect ratio) is
    # wrong on many terminals, so the text lands in the wrong row or off-pane.
    # Instead we bound the image with --use-window-size (pretend the window is
    # cols × cap cells) and let icat do what it does by default: move the cursor
    # to the line right AFTER the image. The text then always follows directly,
    # no math, whatever the real cell size.
    if [[ "${YOUTUBE_FZF_IMG:-}" != "chafa" ]] && command -v kitten >/dev/null 2>&1; then
      # Pixels-per-cell, used only to give --use-window-size a plausible pixel
      # box (icat fits by the smaller of cell/pixel bounds). Query the terminal;
      # fall back to a typical 8×16 cell if that's unavailable.
      wpx=8 hpx=16
      read -r _cw _ch _pw _ph < <(kitten icat --print-window-size 2>/dev/null | tr 'x,' '   ') || true
      [[ "${_cw:-}" =~ ^[0-9]+$ && "${_pw:-}" =~ ^[0-9]+$ && "$_cw" -gt 0 ]] && wpx=$((_pw / _cw))
      [[ "${_ch:-}" =~ ^[0-9]+$ && "${_ph:-}" =~ ^[0-9]+$ && "$_ch" -gt 0 ]] && hpx=$((_ph / _ch))
      ((wpx > 0)) || wpx=8
      ((hpx > 0)) || hpx=16
      kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no \
        --use-window-size "${cols},${cap},$((cols * wpx)),$((cap * hpx))" \
        "$thumb" 2>/dev/null &&
        drew_image=true
    fi
    if [[ "$drew_image" == false ]] && command -v chafa >/dev/null 2>&1; then
      # chafa advances the cursor past the image on its own too, so again no pad.
      chafa --clear --format=symbols --size="${cols}x${cap}" "$thumb" 2>/dev/null &&
        drew_image=true
    fi
  fi

  # Show duration first (one line, no blank gap) so it stays visible even when
  # the title wraps and the image has eaten half the pane height. Channel (when
  # known — history/later rows, once enriched) goes on its own line under it.
  [[ -n "$duration" && "$duration" != "NA" ]] && printf 'Duration: %s\n' "$duration"
  [[ -n "$channel" && "$channel" != "NA" ]] && printf 'Channel: %s\n' "$channel"
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

  print_tmpl="%(ie_key)s${tab}%(id)s${tab}%(channel)s${tab}%(uploader_id)s${tab}%(title)s${tab}%(duration_string)s${tab}%(live_status)s"
  # awk turns each yt-dlp row into our 6-column TSV: YoutubeTab rows render as
  # channels (◉, drill-down), Youtube rows as videos (▶). Order is preserved.
  # Live streams come through as Youtube rows too (they're kept, not excluded);
  # an active live has no duration, so we badge it so it's distinguishable:
  #   is_live -> red ● LIVE,  was_live/post_live -> dim "live" instead of a dur.
  render='
    BEGIN { FS=OFS="\t" }
    {
      ie=$1; id=$2; channel=$3; handle=$4; title=$5; dur=$6; live=$7
      if (handle=="NA") handle=""
      if (dur=="NA")    dur=""
      if (live=="NA")   live=""
      if (ie=="YoutubeTab" && id!="" && id!="NA") {
        disp="\033[36m◉\033[0m  " channel
        if (handle!="") disp=disp "  \033[2m" handle "\033[0m"
        print "channel", id, handle, channel, "", disp
      } else if (ie=="Youtube" && id!="" && id!="NA") {
        disp="▶  " title
        if (live=="is_live") {
          disp=disp "  \033[31m● LIVE\033[0m"
        } else if (live=="was_live" || live=="post_live") {
          disp=disp "  \033[2m" (dur!="" ? dur " · " : "") "was live\033[0m"
        } else if (dur!="") {
          disp=disp "  \033[2m" dur "\033[0m"
        }
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

# Emit the logged-in watch history as the SAME 6-column TSV the search picker
# uses, so Ctrl-H inside search_live can reload straight into it and Enter opens
# a row as a video. Reads the session from the browser's cookies (no OAuth), and
# dedupes the feed's repeated rows (re-watches/day groupings), newest first.
#
# Called as: --ythistory [cache_file] [query]
#   - With no args: fetch from YouTube and print the rows (used on Ctrl-H).
#   - With a cache_file: cache the fetched rows there on first call, then on
#     later calls filter that cache locally by [query] (fzf fuzzy) instead of
#     re-hitting YouTube — this is what makes typing search WITHIN history.
# Turn a stream of "id<TAB>title<TAB>dur<TAB>channel" rows into the shared
# 6-column picker TSV, deduping by id (newest first). channel may be empty (the
# flat feed doesn't carry it — it's filled in later by --ytenrich). Columns:
#   1 kind(video) 2 id 3 channel 4 title 5 dur 6 display
# Column 3 holds the channel (the "handle" slot, unused for videos) so the
# preview can show it. Column 6 is what fzf shows AND matches; the dimmed
# "dur · channel" span there is why typing a channel name filters to it.
yt_rows_awk='
  BEGIN { FS=OFS="\t" }
  !seen[$1]++ {
    id=$1; title=$2; dur=$3; channel=$4
    if (dur=="NA") dur=""
    if (channel=="NA") channel=""
    disp="▶  " title
    meta=dur
    if (channel!="") meta=(meta!="" ? meta " · " channel : channel)
    if (meta!="") disp=disp "  \033[2m" meta "\033[0m"
    print "video", id, channel, title, dur, disp
  }'

# Background channel enrichment. The flat history/WL listing returns NO channel
# (yt-dlp gives channel=NA without a per-video fetch), so the first list shows
# titles only. This mode runs detached after the cache is written: it fetches
# each video's channel with a POOL of parallel yt-dlp calls (xargs -P) and
# rewrites the cache in place — progressively, so channels (and channel search)
# light up batch by batch instead of all at once ~20s later. The picker picks up
# the new rows on its next reload (any keystroke).
#
# Called as: --ytenrich <cache_file>
if [[ "${1:-}" == "--ytenrich" ]]; then
  tab=$'\t'
  cache_file="${2:-}"
  cookies_browser="${YOUTUBE_FZF_COOKIES_BROWSER:-firefox}"
  [[ -s "$cache_file" ]] || exit 0
  # A lock so two reloads can't launch overlapping enrichers for one cache.
  lock="$cache_file.enriching"
  (
    set -o noclobber
    : >"$lock"
  ) 2>/dev/null || exit 0
  map_file="$(mktemp -t yt-chanmap.XXXXXX)"
  fetch_pid=""
  # Clean temp/lock and stop the fetch pool on any exit. Kill the fetch process
  # GROUP (-pid) so the xargs workers die with us, not just xargs itself.
  trap 'rm -f "$lock" "$map_file" "$cache_file".tmp.*; [[ -n "$fetch_pid" ]] && kill -- -"$fetch_pid" 2>/dev/null' EXIT

  # Rejoin the (possibly partial) id→channel map onto the cache by id and rebuild
  # col 3 (channel, for the preview) + col 6 (the dimmed span). Atomic mv, and
  # never resurrect a cache the picker already cleaned up.
  rejoin() {
    [[ -s "$map_file" && -e "$cache_file" ]] || return 0
    local tmp="$cache_file.tmp.$$"
    awk -F"$tab" -v OFS="$tab" '
      NR==FNR { if ($2!="" && $2!="NA") chan[$1]=$2; next }
      {
        id=$2; title=$4; dur=$5
        # Prefer a freshly-resolved channel; otherwise keep whatever col 3 had.
        channel=(id in chan ? chan[id] : $3)
        disp="▶  " title
        meta=dur
        if (channel!="") meta=(meta!="" ? meta " · " channel : channel)
        if (meta!="") disp=disp "  \033[2m" meta "\033[0m"
        print $1, id, channel, title, dur, disp
      }' "$map_file" "$cache_file" >"$tmp" 2>/dev/null || true
    if [[ -s "$tmp" && -e "$cache_file" ]]; then mv "$tmp" "$cache_file"; else rm -f "$tmp"; fi
  }

  # Fetch the channel for each id with a pool of parallel yt-dlp calls, each
  # appending "id<TAB>channel" to the map as it resolves. -P 8 cuts ~34 videos
  # from >50s serial to ~20s. --ignore-no-formats-error: we only want metadata,
  # and some videos expose no format to the cookie session (age/region gated),
  # which would otherwise error the row out before --print runs. -- guards ids
  # that start with "-".
  # setsid puts the whole pipeline in its own process group so the EXIT trap can
  # kill the pool (xargs + all yt-dlp workers) with one group kill.
  YT_TAB="$tab" YT_CB="$cookies_browser" YT_CACHE="$cache_file" \
    setsid sh -c '
      cut -f2 "$YT_CACHE" | xargs -P 8 -I{} -- \
        sh -c "yt-dlp --no-warnings --skip-download --ignore-errors --ignore-no-formats-error \
          --cookies-from-browser \"\$YT_CB\" \
          --print \"%(id)s\$YT_TAB%(channel)s\" \
          -- \"https://www.youtube.com/watch?v=\$1\" 2>/dev/null" _ {}
    ' >>"$map_file" &
  fetch_pid=$!

  # While the pool runs, rejoin every few seconds so channels appear in batches.
  while kill -0 "$fetch_pid" 2>/dev/null; do
    command sleep 3
    rejoin
  done
  wait "$fetch_pid" 2>/dev/null || true
  rejoin # final pass picks up whatever resolved after the last tick
  exit 0
fi

# Shared body for the history / "Watch later" picker sources. Both emit the
# SAME 6-column TSV the search picker uses (kind=video), so Enter opens a row
# like any other video. Reads the logged-in session from the browser's cookies
# (no OAuth); WL is private and history is per-account.
#
# Called as: --ythistory|--ytwatchlater [cache_file] [query]
#   - no cache_file : fetch from YouTube and print rows (used on Ctrl-H/Ctrl-L).
#   - cache_file    : populate it once, kick off background channel enrichment,
#                     then on later calls filter that cache locally by [query]
#                     (fzf fuzzy) instead of re-hitting YouTube — this is what
#                     makes typing search WITHIN history / later.
if [[ "${1:-}" == "--ythistory" || "${1:-}" == "--ytwatchlater" ]]; then
  tab=$'\t'
  cookies_browser="${YOUTUBE_FZF_COOKIES_BROWSER:-firefox}"
  cache_file="${2:-}"
  query="${3:-}"
  if [[ "$1" == "--ythistory" ]]; then
    feed_url="https://www.youtube.com/feed/history"
    feed_end=40
  else
    feed_url="https://www.youtube.com/playlist?list=WL"
    feed_end=100
  fi
  emit_feed() {
    yt-dlp --flat-playlist --no-warnings --playlist-end "$feed_end" \
      --cookies-from-browser "$cookies_browser" \
      --print "%(id)s${tab}%(title)s${tab}%(duration_string)s${tab}%(channel)s" \
      "$feed_url" 2>/dev/null |
      awk "$yt_rows_awk"
  }
  if [[ -n "$cache_file" ]]; then
    # Populate the cache once (first press), then enrich channels in the
    # background so the list shows instantly and channel search lights up shortly
    # after. Reuse the cache for every keystroke that follows.
    if [[ ! -s "$cache_file" ]]; then
      emit_feed >"$cache_file"
      # </dev/null: the enricher (and its yt-dlp pool) runs ~20s after the
      # picker may have exited; an inherited panel tty on stdin would keep the
      # QAT window open that whole time (kitty close_on_child_death=no).
      [[ -s "$cache_file" ]] &&
        setsid -f "$script_self" --ytenrich "$cache_file" </dev/null >/dev/null 2>&1
    fi
    if [[ -n "$query" ]]; then
      # Match against column 6, which holds the title + dimmed duration·channel.
      # --ansi strips the escape codes so the query matches the visible text only
      # (so e.g. typing a channel name filters to that channel's videos).
      # fzf --filter exits 1 on no match; that just means "no rows" to the
      # picker, so don't let set -e treat an empty result as a failure.
      fzf --ansi --filter="$query" --delimiter=$'\t' --with-nth=6 <"$cache_file" || true
    else
      cat "$cache_file"
    fi
  else
    emit_feed
  fi
  exit 0
fi

# Turn 4-column id/title/dur/live_status rows (a yt-dlp --print dump) into the
# 3-column id/title/dur shape the channel picker consumes, baking a live badge
# into the title column (the one fzf shows) so an active live / past live is
# distinguishable — an active live has no duration, so without this it would
# look like a plain video. Shared by --yttab and the main channel fetch.
live_badge_awk='
  BEGIN { FS=OFS="\t" }
  {
    title=$2; live=$4
    if (live=="is_live")                            title=title "  \033[31m● LIVE\033[0m"
    else if (live=="was_live" || live=="post_live") title=title "  \033[2m(was live)\033[0m"
    print $1, title, $3
  }'

# Fetch ONE tab of a channel (videos or streams) and print the 3-column
# id/title/dur rows the channel picker consumes, with a live badge baked into
# the title. Caches per-tab so the Ctrl-S toggle is instant on re-toggle.
#
# Called as: --yttab <videos|streams> <channel_base> <cache_file>
#   channel_base — channel URL WITHOUT a trailing /videos|/streams (e.g.
#                  https://www.youtube.com/@handle). The tab is appended here.
# The streams tab is where YouTube keeps live / past-live content; the videos
# tab is uploads only. This subcommand is what makes Ctrl-S flip between them.
if [[ "${1:-}" == "--yttab" ]]; then
  tab=$'\t'
  which_tab="${2:-videos}"
  channel_base="${3:-}"
  cache_file="${4:-}"
  limit="${YOUTUBE_FZF_LIMIT:-40}"
  [[ -n "$channel_base" ]] || exit 0

  # Reuse a fresh per-tab cache; otherwise fetch. Same 6h staleness as the main
  # path. The picker re-toggling within a session hits the cache and is instant.
  if [[ -n "$cache_file" && -s "$cache_file" ]] &&
    [[ -z "$(find "$cache_file" -mmin +360 2>/dev/null)" ]]; then
    cat "$cache_file"
    exit 0
  fi

  rows="$(yt-dlp --flat-playlist --no-warnings --playlist-end "$limit" \
    --print "%(id)s${tab}%(title)s${tab}%(duration_string)s${tab}%(live_status)s" \
    "${channel_base}/${which_tab}" 2>/dev/null |
    awk "$live_badge_awk")"
  [[ -n "$rows" ]] || exit 0
  if [[ -n "$cache_file" ]]; then
    printf '%s\n' "$rows" >"$cache_file"
  fi
  printf '%s\n' "$rows"
  exit 0
fi

usage() {
  cat <<'EOF'
Fuzzy-find YouTube videos by channel or playlist and open the pick in the
browser.

Usage:
  youtube.sh <channel>            # @handle, channel URL, or channel name
                                  # (Ctrl-S in the list toggles videos/streams)
  youtube.sh -s [query]           # live YouTube search (videos + channels); a
                                  # video opens, a channel drills into its videos
  youtube.sh -p <playlist>        # playlist URL or ID (public only)
  youtube.sh -H                   # your YouTube watch history (logged-in)
  youtube.sh -r <channel>         # refresh cache for that channel/playlist
  youtube.sh -n <count> <channel> # limit how many recent videos to list

Notes:
  - Uses yt-dlp. For channels/playlists/search it sees PUBLIC data only:
    channel uploads and public / unlisted playlists.
  - Watch history (-H) reads your logged-in session from the browser's
    cookies (yt-dlp --cookies-from-browser), so it needs you signed into
    YouTube in that browser. No OAuth required.
EOF
  exit "${1:-0}"
}

for tool in yt-dlp fzf; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is not installed." >&2
    exit 1
  fi
done

while getopts ":spn:rhH" opt; do
  case "$opt" in
  s) mode="search" ;;
  p) mode="playlist" ;;
  H) mode="history" ;;
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

# (source_fzf_colors and switch_to_english come from lib.sh)

# Open a video in the browser on workspace 4, then focus it.
#
# A video search always wants a fresh watch, so this never reuses an existing
# tab. How it lands the video depends on where Firefox already is:
#   - Firefox running on another workspace -> open a brand-NEW window on ws4 and
#     move only that window there, leaving the existing Firefox windows untouched.
#   - Firefox only on ws4 (or cold start)  -> xdg-open a tab and pull Firefox to
#     ws4 if needed.
#
# setsid detaches the cold-start xdg-open so it survives this script exiting —
# otherwise the QAT panel closing the instant we exit would kill it before the
# browser picks up the URL. Best-effort: no-ops outside Hyprland.
#
# Everything past the initial xdg-open involves sleeps and polling loops (up to
# ~2.6s of settle + window-appearance waits). Running that in the foreground
# keeps THIS script alive, and since the kitty QAT panel only closes when the
# script exits, the panel lingers showing the now-dead fzf frame ("empty fzf
# terminal"). So we do all the slow Hyprland window-shuffling in a DETACHED
# background subshell (setsid) and return immediately — the panel closes at once
# while Firefox placement finishes on its own.
#
# </dev/null matters as much as setsid: with kitty's default
# close_on_child_death=no the panel window stays open while ANY process still
# holds its tty, and an inherited stdin is exactly such a hold. Worse, a
# cold-started Firefox would inherit that stdin too, tying it to the panel — so
# force-closing the panel would then kill Firefox (and the just-opened tab).
open_video() {
  local url="https://www.youtube.com/watch?v=$1"

  if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    setsid -f xdg-open "$url" </dev/null >/dev/null 2>&1
    return 0
  fi

  setsid -f bash -c '
    source "$1" # lib.sh: firefox window helpers
    url="$2"
    ws="$3"

    # The QAT panel hides asynchronously; settle briefly so Hyprland does not
    # re-grab focus after us.
    sleep 0.15

    # Firefox is up and has a window off ws4 -> open the video as its OWN new
    # window on ws4 so the existing Firefox windows stay where they are.
    if [[ -n "$(firefox_window_off_workspace "$ws")" ]]; then
      open_in_new_firefox_window "$url" "$ws"
      exit 0
    fi

    # Firefox only on ws4, or cold start: open a tab and pull Firefox to ws4.
    xdg-open "$url" >/dev/null 2>&1
    move_firefox_when_up "$ws"
  ' _ "$script_dir/lib.sh" "$url" "$firefox_workspace" </dev/null >/dev/null 2>&1
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
  # (state files are cleaned by the RETURN trap set up with $vi_file below)

  # The "source" decides what typing searches: live YouTube (search), or WITHIN
  # the loaded history / watch-later list. Ctrl-H/Ctrl-L flip it; Ctrl-T (and a
  # fresh search) flip it back to "search". The change bind reads this to pick
  # which command a keystroke reloads. Cache files hold the once-fetched
  # history/later rows so per-keystroke filtering stays local (no re-fetch).
  local source_file history_cache watchlater_cache
  source_file="$(mktemp -t yt-source.XXXXXX)"
  printf 'search' >"$source_file"
  history_cache="$(mktemp -t yt-history.XXXXXX)"
  watchlater_cache="$(mktemp -t yt-watchlater.XXXXXX)"

  # The reload binds call --ytsearch with the mode read from $mode_file, so a
  # Ctrl-T flip takes effect on the very next reload without re-launching fzf.
  local search_cmd="\"$script_self\" --ytsearch \"\$(cat '$mode_file')\" {q}"
  # Ctrl-H / Ctrl-L load the watch history / "Watch later" playlist into the same
  # picker (rows are emitted in the search format, kind=video, so Enter opens them
  # like any other video). The cache-file arg makes the FIRST call fetch+cache and
  # the {q} arg lets later calls (from the change bind) filter that cache locally.
  local history_cmd="\"$script_self\" --ythistory '$history_cache' {q}"
  local watchlater_cmd="\"$script_self\" --ytwatchlater '$watchlater_cache' {q}"

  # Seed the list with the initial query; change:reload refreshes it as typed.
  # --preview only makes sense for videos (col 2 = video id); for channels the
  # id is a UC… channel id and open_video isn't used, so the preview just shows
  # nothing useful — that's fine.
  #
  # Ctrl-C / Ctrl-V pick the search mode explicitly (channels / videos). Each
  # rewrites the mode file, updates the prompt, and re-runs the search in that
  # mode for the same query. Choosing a mode implies live search, so both also
  # flip the source back to "search" — this is how you leave history/later
  # browsing and return to querying YouTube.
  local set_channels="execute-silent(printf search >'$source_file'; printf channels >'$mode_file')+change-prompt(Search channels > )+reload($search_cmd)+first"
  local set_videos="execute-silent(printf search >'$source_file'; printf videos >'$mode_file')+change-prompt(Search YouTube > )+reload($search_cmd)+first"

  # The change bind (a keystroke) is source-aware: in "search" it live-queries
  # YouTube; in "history"/"later" it filters the already-loaded list locally.
  # The brief sleep debounces fast typing (same as the old static change bind).
  local change_action="transform:
    case \"\$(cat '$source_file')\" in
      history) echo \"reload(sleep 0.2; $history_cmd)+first\" ;;
      later)   echo \"reload(sleep 0.2; $watchlater_cmd)+first\" ;;
      *)       echo \"reload(sleep 0.3; $search_cmd)+first\" ;;
    esac"

  # Vim-style modes. Insert mode (default): you type and every keystroke
  # re-queries YouTube (change:reload), letters go into the query. Esc enters
  # normal mode: typing stops re-querying and j/k/g/G navigate, i/ returns to
  # insert, q or Esc quits.
  #
  # fzf binds are global, so a mode is just "which binds are active". We swap
  # them with rebind/unbind on the mode transitions:
  #   - j/k/g/G are navigation actions, but start UNBOUND so they type as
  #     letters in insert mode; normal mode rebinds them to nav.
  #   - esc is rebound per mode: insert's esc -> normal, normal's esc -> abort.
  #   - change (the live re-query) is unbound in normal mode so j/k don't fire it.
  local insert_header="INSERT · Esc normal · ^V videos · ^C channels · ^H history · ^L later"
  local normal_header="NORMAL · j/k move · g/G top/bottom · i insert · Enter open · q/Esc quit"
  # Mode transitions. fzf's rebind restores a key's ORIGINAL action, so esc can't
  # be flipped between "go normal" and "quit" with rebind alone — instead esc
  # runs a transform that reads the current mode from $vi_file and acts on it:
  # insert -> normal, normal -> abort. enter_normal/enter_insert just flip the
  # nav keys + the live-query bind + the mode file + the header.
  local vi_file
  vi_file="$(mktemp -t yt-vi-mode.XXXXXX)"
  printf insert >"$vi_file"
  trap 'rm -f "$mode_file" "$vi_file" "$source_file" "$history_cache" "$watchlater_cache"' RETURN

  local enter_normal="execute-silent(printf normal >'$vi_file')+unbind(change)+rebind(j,k,g,G,q,i)+change-header($normal_header)"
  local enter_insert="execute-silent(printf insert >'$vi_file')+unbind(j,k,g,G,q,i)+rebind(change)+change-header($insert_header)"
  local esc_action="transform:
    if [[ \"\$(cat '$vi_file')\" == insert ]]; then
      echo \"$enter_normal\"
    else
      echo abort
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
    --header="$insert_header"
    # Start in insert: live re-query on, nav keys off (so they type as letters).
    # i is included so the letter "i" types in insert mode; normal mode rebinds it.
    --bind "start:reload($search_cmd)+unbind(j,k,g,G,q,i)"
    --bind "change:$change_action"
    # Ctrl-V videos / Ctrl-C channels: pick the live-search mode explicitly.
    # (Binding ctrl-c here overrides its usual abort; quit is Esc/q.)
    --bind "ctrl-v:$set_videos"
    --bind "ctrl-c:$set_channels"
    # Ctrl-H/Ctrl-L switch the source so typing searches WITHIN that list. They
    # clear the query first so the full list shows, then reload (empty {q} =
    # unfiltered). The first call fetches+caches; later keystrokes filter locally.
    --bind "ctrl-h:execute-silent(printf history >'$source_file')+change-prompt(Search history > )+clear-query+reload($history_cmd)+first"
    --bind "ctrl-l:execute-silent(printf later >'$source_file')+change-prompt(Search later > )+clear-query+reload($watchlater_cmd)+first"
    # esc: insert -> normal, normal -> quit (via the mode-aware transform).
    --bind "esc:$esc_action"
    # Navigation actions, unbound at start (insert types them), rebound in normal.
    --bind "j:down"
    --bind "k:up"
    --bind "g:first"
    --bind "G:last"
    --bind "q:abort"
    --bind "i:$enter_insert"
    # Args: id title dur channel (col 3 carries the channel for history/later).
    --preview "\"$script_self\" --preview {2} {4} {5} {3}"
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
elif [[ "$mode" == "history" ]]; then
  # History takes no positional argument; the source is your account feed.
  target="watch history"
else
  target="${1:-}"
fi

if [[ -z "$target" ]]; then
  usage 1
fi

# Build the source URL yt-dlp should enumerate.
if [[ "$mode" == "history" ]]; then
  source_url="https://www.youtube.com/feed/history"
  cache_key="history"
  # History is volatile (changes as you watch), so never serve it stale.
  refresh=true
elif [[ "$mode" == "playlist" ]]; then
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
  # Channel base (URL without a trailing /videos|/streams) so the Ctrl-S toggle
  # can swap tabs by appending the other one. Only channels have a streams tab.
  channel_base="${source_url%/videos}"
  channel_base="${channel_base%/streams}"
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
  yt_args=(--flat-playlist --no-warnings
    --playlist-end "$limit"
    --print "%(id)s${tab}%(title)s${tab}%(duration_string)s${tab}%(live_status)s")
  # History needs your logged-in session, read from the browser's cookies.
  [[ "$mode" == "history" ]] && yt_args+=(--cookies-from-browser "$cookies_browser")

  if ! yt-dlp "${yt_args[@]}" "$source_url" >"$cache_file.tmp" 2>/dev/null; then
    rm -f "$cache_file.tmp"
    echo "Could not fetch videos for: $target" >&2
    exit 1
  fi
  # Bake a live badge into the title column (col 2, the one fzf shows) so an
  # active live / past live is distinguishable here too — an active live has no
  # duration, so without this it looks like a plain video. Drop col 4 afterwards
  # so the cache keeps its 3-column id/title/dur shape (preview args {1} {2} {3}).
  awk -F"$tab" -v OFS="$tab" '
    {
      title=$2; live=$4
      if (live=="is_live")                       title=title "  \033[31m● LIVE\033[0m"
      else if (live=="was_live" || live=="post_live") title=title "  \033[2m(was live)\033[0m"
      print $1, title, $3
    }' "$cache_file.tmp" >"$cache_file.tmp3" && mv "$cache_file.tmp3" "$cache_file.tmp"
  # The history feed repeats videos (re-watches, day groupings); collapse to the
  # first occurrence of each id while keeping most-recent-first order.
  if [[ "$mode" == "history" ]]; then
    awk -F"$tab" '!seen[$1]++' "$cache_file.tmp" >"$cache_file.tmp2" &&
      mv "$cache_file.tmp2" "$cache_file.tmp"
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

base_header="$target — Enter to open in browser, Esc to cancel"
fzf_args=(
  --height=100%
  --reverse
  --ansi
  --delimiter=$'\t'
  --with-nth=2
  --prompt="Open video > "
  --header="$base_header"
  --preview "$script_self --preview {1} {2} {3}"
  --preview-window "right,55%,wrap"
)

# Ctrl-S: in channel mode, flip between the channel's videos tab and its streams
# tab (where YouTube keeps live / past-live content; the videos tab is uploads
# only). The current tab lives in a temp file so the static reload bind can read
# it; --yttab fetches+caches per tab, so re-toggling is instant. Not offered for
# playlists/history, which have no streams tab.
if [[ -n "${channel_base:-}" ]]; then
  tab_file="$(mktemp -t yt-chtab.XXXXXX)"
  printf videos >"$tab_file"
  streams_cache="${cache_file%.tsv}.streams.tsv"
  export YOUTUBE_FZF_LIMIT="$limit" # so the streams tab honors -n too
  videos_cmd="\"$script_self\" --yttab videos '$channel_base' '$cache_file'"
  streams_cmd="\"$script_self\" --yttab streams '$channel_base' '$streams_cache'"
  ctrl_s_toggle="transform:
    if [[ \"\$(cat '$tab_file')\" == videos ]]; then
      printf streams >'$tab_file'
      echo \"change-prompt(Open stream > )+change-header($target · STREAMS — Enter open, ^S videos, Esc cancel)+reload($streams_cmd)+first\"
    else
      printf videos >'$tab_file'
      echo \"change-prompt(Open video > )+change-header($base_header · ^S streams)+reload($videos_cmd)+first\"
    fi"
  fzf_args+=(
    --header="$base_header · ^S streams"
    --bind "ctrl-s:$ctrl_s_toggle"
  )
  trap 'rm -f "$tab_file"' EXIT
fi

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
