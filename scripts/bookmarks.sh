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
# brotab CLI (installed via pipx). Used to focus an already-open browser tab
# instead of opening a duplicate. Optional: if missing we fall back to xdg-open.
brotab_bin="$(command -v bt || echo "$HOME/.local/bin/bt")"
bookmarks_group="bookmarks"
# Workspace a cold-started Firefox should land on, and the fallback workspace for
# new tabs when Firefox only has windows on the YouTube workspace. When Firefox
# already has a window elsewhere we leave it where it is and open the tab there.
firefox_workspace="2"
# Workspace reserved exclusively for YouTube. New bookmark tabs must never open
# here: if the only Firefox window lives on it, we move that window to
# firefox_workspace first. (Already-open tabs found via brotab are still
# activated wherever they are, including here.)
youtube_workspace="4"
# Recently-opened log (most recent first), one "name<tab>url" row per opened
# bookmark. Shown when the query is empty so the picker opens to "recents"
# instead of the "type 3 chars" empty state — mirrors apps.sh's recent ordering.
cache_dir="$HOME/.cache/bookmarks-fzf"
recent_file="$cache_dir/recent.tsv"
recent_max=50

# Print every bookmark row from all sources (the full search list). Used when a
# query is typed. Kept as its own subcommand so fzf can reload it cheaply.
all_bookmarks() {
  local bookmarks_file
  for bookmarks_file in "${bookmarks_files[@]}"; do
    [[ -s "$bookmarks_file" ]] && cat "$bookmarks_file"
  done
}

# Print the recently-opened bookmarks, most recent first. Stale rows (a bookmark
# that has since been removed from every source) are dropped by intersecting the
# log against the live catalog on url. Shown when the query is empty.
recent_bookmarks() {
  [[ -s "$recent_file" ]] || return 0
  awk -F'\t' -v recent="$recent_file" '
    # First pass: remember every url that still exists in the catalog.
    { live[$2] = 1 }
    END {
      while ((getline line < recent) > 0) {
        split(line, r, "\t")
        url = r[2]
        if (url != "" && (url in live) && !(url in seen)) {
          seen[url] = 1
          print line
        }
      }
    }
  ' <(all_bookmarks)
}

# Record an opened bookmark at the top of the recents log, de-duplicating by url
# and capping the file length. Rewrites recent_file atomically.
record_open() {
  local name="$1" url="$2" tmp
  [[ -n "$url" ]] || return 0
  mkdir -p "$cache_dir"
  [[ -f "$recent_file" ]] || : >"$recent_file"
  tmp="$(mktemp "$cache_dir/recent.XXXXXX")" || return 0
  {
    printf '%s\t%s\n' "$name" "$url"
    # Keep prior rows except the one we just promoted; cap total lines.
    awk -F'\t' -v url="$url" '$2 != url' "$recent_file"
  } | head -n "$recent_max" >"$tmp"
  mv "$tmp" "$recent_file"
}

# Force the keyboard to English so fzf search matches latin bookmark names even
# when the active layout is Russian. Index 0 is "us" in hyprland.conf's kb_layout
# (us,ru). Best-effort: silently no-op outside Hyprland.
switch_to_english() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl switchxkblayout all 0 >/dev/null 2>&1 || true
}

# Normalise a URL for loose comparison: strip scheme, a trailing slash, and any
# #fragment so "https://x.com/" and "http://x.com" match the same open tab.
normalize_url() {
  local u="$1"
  u="${u#http://}"
  u="${u#https://}"
  u="${u%%#*}"
  u="${u%/}"
  printf '%s\n' "$u"
}

# Raise the Firefox window in Hyprland. The QAT panel hides asynchronously, so
# settle briefly first to avoid Hyprland re-grabbing focus after us. When the
# window is not up yet (Firefox starting cold), poll a few times for it.
#
# On a cold start only (Firefox was not already running when we first looked) we
# move the freshly-launched window to firefox_workspace so a new browser opens
# there by default; an already-running Firefox is focused wherever it lives.
#
# Used for the brotab path (a matching tab already exists): we just want the
# browser raised wherever that tab lives, even if that is the YouTube workspace.
focus_firefox() {
  local i cold_start=false
  sleep 0.15

  # If Firefox isn't up on the first check, this open is launching it cold.
  if ! hyprctl clients -j 2>/dev/null | grep -q '"class": *"firefox"'; then
    cold_start=true
  fi

  for i in 1 2 3 4 5 6 7 8 9 10; do
    if hyprctl clients -j 2>/dev/null | grep -q '"class": *"firefox"'; then
      if [[ "$cold_start" == true ]]; then
        hyprctl dispatch movetoworkspace "${firefox_workspace},class:firefox" >/dev/null 2>&1 || true
      fi
      hyprctl dispatch focuswindow class:firefox >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.25
  done
  return 0
}

# Raise the Firefox window whose active tab brotab just activated, identified by
# that tab's title. After activation the tab's title becomes its window's title,
# which Hyprland reports (suffixed with " — Mozilla Firefox"), so we match the
# window whose title starts with the tab title. This is what lets a tab living on
# the YouTube workspace win over some other Firefox window on a different ws.
# Falls back to focus_firefox when no window matches (e.g. title not settled).
focus_firefox_for_title() {
  local title="$1" i addr
  [[ -n "$title" ]] || {
    focus_firefox
    return 0
  }

  # Poll briefly: activation + Hyprland title update are asynchronous.
  for i in 1 2 3 4 5; do
    addr="$(
      hyprctl clients -j 2>/dev/null | jq -r --arg t "$title" '
        .[] | select(.class == "firefox" and (.title | startswith($t))) | .address
      ' 2>/dev/null | head -n1
    )"
    if [[ -n "$addr" ]]; then
      hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.15
  done

  # Title never matched a window; raise some Firefox window so we still leave the
  # picker and land in the browser.
  focus_firefox
  return 0
}

# Print the Hyprland address of a Firefox window that is NOT on the YouTube
# workspace, or nothing if every Firefox window is on it (or none exist). When
# such a window exists we focus it and let xdg-open add a tab there; otherwise
# we open a new window so the YouTube workspace stays YouTube-only.
firefox_window_off_youtube() {
  hyprctl clients -j 2>/dev/null | jq -r --argjson yt "$youtube_workspace" '
    .[] | select(.class == "firefox" and .workspace.id != $yt) | .address
  ' 2>/dev/null | head -n1
}

# Print the Hyprland addresses of all current Firefox windows, one per line.
firefox_window_addresses() {
  hyprctl clients -j 2>/dev/null | jq -r '
    .[] | select(.class == "firefox") | .address
  ' 2>/dev/null
}

# Decide how to deliver a new bookmark tab without ever landing on the YouTube
# workspace, and print the chosen mode for open_or_focus to act on:
#   "tab <address>" - a Firefox window already lives off the YouTube ws; focus it
#                     here and let xdg-open add a tab to it.
#   "newwindow"     - Firefox is running but only on the YouTube ws; the caller
#                     opens a fresh window (firefox --new-window) on ws2 so the
#                     YouTube window is left untouched.
#   "cold"          - no Firefox window yet; the caller launches it and moves the
#                     new window to firefox_workspace.
prepare_firefox_for_new_tab() {
  local addr
  sleep 0.15

  addr="$(firefox_window_off_youtube)"
  if [[ -n "$addr" ]]; then
    # A usable window already lives off the YouTube ws: raise it so xdg-open's
    # tab lands there.
    hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
    printf 'tab\n'
    return 0
  fi

  # No window off the YouTube ws. If Firefox is running, every window is on it ->
  # open a brand-new window on ws2 instead of stealing the YouTube one.
  if hyprctl clients -j 2>/dev/null | grep -q '"class": *"firefox"'; then
    printf 'newwindow\n'
    return 0
  fi

  # Cold start: no window yet.
  printf 'cold\n'
  return 0
}

# Open the URL in a fresh Firefox window, then move that window (and only that
# window) to firefox_workspace and focus it. We diff the window address set
# before/after the launch so the move targets the newly created window rather
# than the existing YouTube one.
open_in_new_window() {
  local url="$1" before after addr i new_addr=""

  before="$(firefox_window_addresses)"
  firefox --new-window "$url" >/dev/null 2>&1 &
  disown

  # Wait for a window address that was not present before the launch.
  for i in 1 2 3 4 5 6 7 8 9 10; do
    after="$(firefox_window_addresses)"
    new_addr="$(comm -13 <(printf '%s\n' "$before" | sort) <(printf '%s\n' "$after" | sort) | head -n1)"
    [[ -n "$new_addr" ]] && break
    sleep 0.25
  done

  if [[ -n "$new_addr" ]]; then
    hyprctl dispatch movetoworkspace "${firefox_workspace},address:$new_addr" >/dev/null 2>&1 || true
    hyprctl dispatch focuswindow "address:$new_addr" >/dev/null 2>&1 || true
  fi
  return 0
}

# After a cold-start xdg-open, poll for the freshly launched Firefox window and
# move it to firefox_workspace, then focus it. Mirrors focus_firefox's cold-start
# branch but is only reached when prepare_firefox_for_new_tab found no window.
focus_after_cold_open() {
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

# Open a bookmark, preferring an already-open browser tab. Asks brotab for the
# list of open tabs; if one matches the target URL, activates that tab and
# focuses Firefox. Otherwise (no match, or brotab unavailable) opens a new tab
# with xdg-open and still raises Firefox. Always returns 0 so the picker loop
# keeps running.
open_or_focus() {
  local url="$1" want match tab_id tab_title

  if [[ -x "$brotab_bin" ]]; then
    want="$(normalize_url "$url")"
    # bt list rows: "<prefix.window.tab>\t<title>\t<url>". Find the first tab
    # whose normalised URL equals the target; emit "<tab id>\t<title>" so we can
    # both activate it and locate its Hyprland window by title afterwards.
    match="$(
      "$brotab_bin" list 2>/dev/null | awk -F'\t' -v want="$want" '
        {
          u = $3
          sub(/^https?:\/\//, "", u)
          sub(/#.*$/, "", u)
          sub(/\/$/, "", u)
          if (u == want) { print $1 "\t" $2; exit }
        }
      '
    )"
    if [[ -n "$match" ]]; then
      IFS=$'\t' read -r tab_id tab_title <<<"$match"
      # --focused tells brotab to focus the browser; on Hyprland that raise is
      # ignored, so we also raise the window ourselves below.
      "$brotab_bin" activate --focused "$tab_id" >/dev/null 2>&1 || true
      # Raise the specific window holding this tab (its title becomes the window
      # title after activation), not just any Firefox window — otherwise a tab on
      # the YouTube ws would be missed in favour of some other Firefox window.
      focus_firefox_for_title "$tab_title"
      return 0
    fi
  fi

  # Not open anywhere (or brotab unavailable): open a new tab/window, keeping it
  # off the YouTube workspace. prepare_firefox_for_new_tab picks the strategy and
  # (for the "tab" case) focuses the target window first, since xdg-open delivers
  # the URL to the most-recently-active Firefox window.
  case "$(prepare_firefox_for_new_tab)" in
  newwindow)
    # Only YouTube-ws windows exist: spawn a fresh window on ws2 instead.
    open_in_new_window "$url"
    ;;
  cold)
    # No Firefox yet: launch it, then move the new window to firefox_workspace.
    xdg-open "$url" >/dev/null 2>&1 &
    disown
    focus_after_cold_open
    ;;
  *)
    # "tab": a window off the YouTube ws is focused; add a tab to it.
    xdg-open "$url" >/dev/null 2>&1 &
    disown
    ;;
  esac
  return 0
}

# Internal list providers invoked by fzf's reload binds. They just print rows
# and exit so reloading on every keystroke stays snappy.
if [[ "${1:-}" == "--recent" ]]; then
  recent_bookmarks
  exit 0
fi
if [[ "${1:-}" == "--all" ]]; then
  all_bookmarks
  exit 0
fi

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

  # Force English here, in the launcher: it runs on EVERY hotkey press
  # (kanata -> bookmarks.sh), so the layout flips to us each time the panel is
  # shown — including toggles, where kitty just re-reveals the existing panel.
  switch_to_english

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

  fzf_args=(
    --height=100%
    --reverse
    --delimiter=$'\t'
    --with-nth=1
    --header="Empty = recent, type to search all"
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

  # Empty query -> recently opened; any typed query -> full catalog. fzf re-runs
  # these subcommands of ourself on start and on every keystroke.
  printf -v quoted_self '%q' "$script_path"
  list_reload="if [[ -z {q} ]]; then $quoted_self --recent; else $quoted_self --all; fi"
  fzf_args+=(--bind "start:reload($list_reload)")
  fzf_args+=(--bind "change:reload($list_reload)")

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

    # Log this open so the bookmark rises to the top of next time's recents.
    record_open "$_name" "$url"

    toggle_bookmarks_qat
    open_or_focus "$url"
  done
fi

launch_bookmarks_qat
