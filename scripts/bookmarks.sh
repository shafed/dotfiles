#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_path="$script_dir/$(basename "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

# Fuzzy-find bookmarks and open the pick in Helium, preferring an already-open
# tab (focused via brotab) over opening a duplicate. Runs inside a long-lived
# kitty quick-access panel toggled via the remote-control socket — same
# mechanism as apps.sh — so it overlays the screen and re-opens instantly.
#
# Usage:
#   bookmarks.sh                  # launch (or toggle) the picker QAT
#   bookmarks.sh --sync-browser   # export browser bookmarks to TSV and exit
#   bookmarks.sh --pick           # internal: picker loop inside the QAT panel
#   bookmarks.sh --recent|--all   # internal: list providers for fzf's reloads

browser_bookmarks_file="$HOME/dotfiles/bookmarks/helium-bookmarks.tsv"
browser_bookmarks_source="${DOTFILES_BROWSER_BOOKMARKS_SOURCE:-$browser_profile_dir/Bookmarks}"
bookmarks_files=(
  "$HOME/dotfiles/bookmarks/bookmarks.tsv"
  "$HOME/dotfiles-private/bookmarks/bookmarks.tsv"
  "$browser_bookmarks_file"
)
bookmarks_group="bookmarks"
# Workspace a cold-started browser should land on, and the fallback workspace for
# new tabs when the browser only has windows on the YouTube workspace. When it
# already has a window elsewhere we leave it where it is and open the tab there.
browser_workspace="2"
# Workspace reserved exclusively for YouTube. New bookmark tabs must never open
# here: if the only browser window lives on it, we open a new window on
# browser_workspace first. (Already-open tabs found via brotab are still
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

# Open a bookmark, preferring an already-open browser tab. Always returns 0 so
# the picker loop keeps running.
open_or_focus() {
  open_or_focus_url "$1" "$browser_workspace" "$youtube_workspace"
}

# Dump Chromium-style browser bookmarks to a TSV the picker can read.
export_browser_bookmarks() {
  command -v jq >/dev/null 2>&1 || return 0
  [[ -f "$browser_bookmarks_source" ]] || return 0

  mkdir -p "$(dirname "$browser_bookmarks_file")"
  local out
  out="$(jq -r '
    [.. | objects
      | select(.type? == "url" and ((.url // "") | startswith("http")))
      | {name: (if ((.name // "") == "") then .url else .name end), url}]
    | reduce .[] as $row ([]; if any(.[]; .url == $row.url) then . else . + [$row] end)
    | .[] | [.name, .url] | @tsv
  ' "$browser_bookmarks_source" 2>/dev/null || true)"

  # Only overwrite when we actually got rows, so a transient read failure does
  # not wipe a previously good export.
  [[ -n "$out" ]] && printf '%s\n' "$out" >"$browser_bookmarks_file"
}

# The picker loop. Runs inside the QAT panel (bookmarks.sh --pick). Keeps the
# process alive after every action so kitty only toggles the panel's visibility
# on the next trigger instead of cold-starting it.
run_picker() {
  # Refresh the browser export before showing the picker so it stays in sync.
  export_browser_bookmarks

  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is not installed."
    read -r -p "Press enter to close. "
    exit 1
  fi

  local bookmarks_file has_bookmarks=false
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

  # Empty query -> recently opened; any typed query -> full catalog. fzf re-runs
  # these subcommands of ourself on start and on every keystroke.
  local quoted_self list_reload
  printf -v quoted_self '%q' "$script_path"
  list_reload="if [[ -z {q} ]]; then $quoted_self --recent; else $quoted_self --all; fi"

  local fzf_args=(
    --height=100%
    --reverse
    --delimiter=$'\t'
    --with-nth=1
    --header="Empty = recent, type to search all"
    --prompt="Open bookmark > "
    --bind "start:reload($list_reload)"
    --bind "change:reload($list_reload)"
  )

  local selected _name url
  while true; do
    # Esc makes fzf exit non-zero. Treat it as "hide and rearm" so the next
    # keypress shows an already-running picker instead of starting from cold.
    # The list itself comes from the reload binds, so feed fzf an empty stdin.
    if ! selected=$(: | fzf "${fzf_args[@]}"); then
      toggle_qat "$bookmarks_group"
      continue
    fi

    IFS=$'\t' read -r _name url <<<"$selected"

    if [[ -z "${url:-}" ]]; then
      echo "Invalid bookmark: $selected"
      read -r -p "Press enter to continue. "
      toggle_qat "$bookmarks_group"
      continue
    fi

    # Log this open so the bookmark rises to the top of next time's recents.
    record_open "$_name" "$url"

    toggle_qat "$bookmarks_group"
    open_or_focus "$url"
  done
}

case "${1:-}" in
# Internal list providers invoked by fzf's reload binds. They just print rows
# and exit so reloading on every keystroke stays snappy.
--recent)
  recent_bookmarks
  ;;
--all)
  all_bookmarks
  ;;
--sync-browser)
  export_browser_bookmarks
  echo "Synced browser bookmarks to $browser_bookmarks_file"
  ;;
--sync-firefox)
  export_browser_bookmarks
  echo "Synced browser bookmarks to $browser_bookmarks_file"
  ;;
--pick)
  run_picker
  ;;
*)
  launch_qat "$bookmarks_group" /usr/bin/env bash "$script_path" --pick
  ;;
esac
