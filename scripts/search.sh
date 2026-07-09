#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_path="$script_dir/$(basename "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

# Pure web-search launcher: type a query, pick a live Google suggestion (or just
# hit Enter on your raw query), and the search opens in Helium — preferring an
# already-open tab over a duplicate, same as bookmarks.sh. No bookmark rows; this
# is the address-bar "search the web" half split out from bookmarks.sh into its
# own independent QAT.
#
# Runs inside a long-lived kitty quick-access panel toggled via the remote-control
# socket — same mechanism as bookmarks.sh / apps.sh — so it overlays the screen
# and re-opens instantly.
#
# Usage:
#   search.sh            # launch (or toggle) the search QAT
#   search.sh --pick     # internal: picker loop inside the QAT panel
#   search.sh --list {q} # internal: suggestion provider for fzf's reloads

search_group="search"

# Workspace a cold-started browser should land on, and the fallback workspace for
# new tabs when the browser only has windows on the YouTube workspace.
browser_workspace="2"
# Workspace reserved exclusively for YouTube. New tabs must never open here: if
# the only browser window lives on it, we open a new window on browser_workspace
# first. (Already-open tabs found via brotab are still activated wherever.)
youtube_workspace="4"

# Search engine the typed query / chosen suggestion is sent to. %s is replaced
# with the URL-encoded query.
search_url_template="https://www.google.com/search?q=%s"

# URL-encode a string for use in a query parameter. Iterates byte-by-byte under
# the C locale so multibyte (UTF-8) characters are percent-escaped per byte,
# yielding valid encodings like %C3%A9 for "é".
urlencode() {
  local s="$1" out="" c i
  local LC_ALL=C
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
    [a-zA-Z0-9.~_-]) out+="$c" ;;
    *)
      printf -v c '%%%02X' "'$c"
      out+="$c"
      ;;
    esac
  done
  printf '%s\n' "$out"
}

# Build a search-engine URL for a raw query string.
search_url_for() {
  local q
  q="$(urlencode "$1")"
  printf "${search_url_template}\n" "$q"
}

# Magnifier icon on every suggestion row so the list reads like a browser address
# bar. The icon lives only in the display column (1); column 2 stays the raw
# suggestion text so the picker loop can URL-encode it cleanly.
suggest_icon="🔍"
# Endpoint for live search suggestions. client=firefox is a Google response
# format selector, not a dependency on the local browser.
suggest_url_template="https://suggestqueries.google.com/complete/search?client=firefox&q=%s"
# Debounce before a suggestion fetch actually hits the network. fzf kills the
# previous reload process on each keystroke, so this leading pause means only a
# lull in typing lets the curl run — no request per character.
suggest_debounce="0.18"
suggest_max=10

# Fetch live search suggestions for a query and print them as picker rows:
# "<icon> <suggestion>\t<suggestion text>". Column 2 holds the raw suggestion;
# the picker loop turns it into a search URL (search_url_for) when it opens a
# row, keeping URL-encoding in bash rather than jq. Prints nothing (and never
# errors) on empty query, missing tools, or no network.
suggest_rows() {
  local q="$1" encoded json
  [[ -n "$q" ]] || return 0
  command -v curl >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0

  # Leading debounce: if the user is still typing, fzf kills us before this
  # returns and no request is made.
  sleep "$suggest_debounce"

  encoded="$(urlencode "$q")"
  json="$(curl -s --max-time 2 "$(printf "$suggest_url_template" "$encoded")" 2>/dev/null)" || return 0
  [[ -n "$json" ]] || return 0

  printf '%s' "$json" | jq -r --arg icon "$suggest_icon" --argjson max "$suggest_max" '
    (.[1] // [])[:$max][]
    | select(. != null and . != "")
    | "\($icon) \(.)\t\(.)"
  ' 2>/dev/null || return 0
}

# Open a URL, preferring an already-open browser tab. Always returns 0 so the
# picker loop keeps running.
open_or_focus() {
  open_or_focus_url "$1" "$browser_workspace" "$youtube_workspace"
}

# The picker loop. Runs inside the QAT panel (search.sh --pick). Keeps the
# process alive after every action so kitty only toggles the panel's visibility
# on the next trigger instead of cold-starting it.
run_picker() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is not installed."
    read -r -p "Press enter to close. "
    exit 1
  fi

  # fzf re-runs this subcommand of ourself on start and on every keystroke,
  # passing the current query. --list returns the live web suggestions.
  local quoted_self list_reload
  printf -v quoted_self '%q' "$script_path"
  list_reload="$quoted_self --list {q}"

  local fzf_args=(
    --height=100%
    --reverse
    --delimiter=$'\t'
    --with-nth=1
    --print-query
    # We feed fzf the final list ourselves, so disable its own filtering. {q}
    # still reflects the typed query for the reload binds.
    --disabled
    --header="🔍 web search · Enter on your query searches it · or pick a suggestion"
    --prompt="Search the web > "
    --bind "start:reload($list_reload)"
    --bind "change:reload($list_reload)"
  )

  local out rc query selected _disp suggestion
  while true; do
    # --print-query emits the typed query as the first output line, then the
    # selected row (if any). Exit codes: 0 = row selected, 1 = no match,
    # 130 = aborted (Esc). The list comes from the reload binds, so empty stdin.
    out=$(: | fzf "${fzf_args[@]}") && rc=0 || rc=$?

    # Esc: hide and rearm so the next keypress shows the running picker.
    if [[ "$rc" -eq 130 ]]; then
      toggle_qat "$search_group"
      continue
    fi

    query="${out%%$'\n'*}"
    selected=""
    [[ "$out" == *$'\n'* ]] && selected="${out#*$'\n'}"

    # A suggestion row was chosen: search for that suggestion's text (col 2).
    if [[ "$rc" -eq 0 && -n "$selected" ]]; then
      IFS=$'\t' read -r _disp suggestion <<<"$selected"
      if [[ -n "$suggestion" ]]; then
        toggle_qat "$search_group"
        open_or_focus "$(search_url_for "$suggestion")"
        continue
      fi
    fi

    # No row selected (Enter on raw query, or no suggestions yet): search the
    # typed query verbatim. Empty query just hides the panel.
    toggle_qat "$search_group"
    [[ -n "$query" ]] && open_or_focus "$(search_url_for "$query")"
  done
}

case "${1:-}" in
--list)
  # Suggestion provider for fzf's reload binds: live web suggestions for the
  # (possibly empty) query in $2.
  suggest_rows "${2:-}"
  ;;
--pick)
  run_picker
  ;;
*)
  launch_qat "$search_group" /usr/bin/env bash "$script_path" --pick
  ;;
esac
