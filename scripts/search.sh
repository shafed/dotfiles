#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_path="$script_dir/$(basename "${BASH_SOURCE[0]}")"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

# Pure web-search launcher: type a query, pick a live Google suggestion (or just
# hit Enter on your raw query), and the search opens in Firefox — preferring an
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

# brotab CLI (installed via pipx). Used to focus an already-open browser tab
# instead of opening a duplicate. Optional: if missing we fall back to xdg-open.
brotab_bin="$(command -v bt || echo "$HOME/.local/bin/bt")"
# Workspace a cold-started Firefox should land on, and the fallback workspace for
# new tabs when Firefox only has windows on the YouTube workspace.
firefox_workspace="2"
# Workspace reserved exclusively for YouTube. New tabs must never open here: if
# the only Firefox window lives on it, we move that window to firefox_workspace
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
# Endpoint for live search suggestions. client=firefox returns simple JSON:
# [query, [suggestion, ...], ...]. Tunable alongside search_url_template.
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
# window is not up yet (Firefox starting cold), poll a few times for it. On a
# cold start only we move the freshly-launched window to firefox_workspace.
focus_firefox() {
  local i cold_start=false
  sleep 0.15

  if ! firefox_running; then
    cold_start=true
  fi

  for i in {1..10}; do
    if firefox_running; then
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
# that tab's title (which becomes the window title after activation, suffixed
# with " — Mozilla Firefox"). Falls back to focus_firefox when no window matches.
focus_firefox_for_title() {
  local title="$1" i addr
  [[ -n "$title" ]] || {
    focus_firefox
    return 0
  }

  for i in {1..5}; do
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

  focus_firefox
  return 0
}

# Decide how to deliver a new tab without ever landing on the YouTube workspace,
# and print the chosen mode for open_or_focus to act on:
#   "tab"       - a Firefox window already lives off the YouTube ws; focus it
#                 here and let xdg-open add a tab to it.
#   "newwindow" - Firefox is running but only on the YouTube ws; open a fresh
#                 window on firefox_workspace so the YouTube window is untouched.
#   "cold"      - no Firefox window yet; launch it and move the new window over.
prepare_firefox_for_new_tab() {
  local addr
  sleep 0.15

  addr="$(firefox_window_off_workspace "$youtube_workspace")"
  if [[ -n "$addr" ]]; then
    hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
    printf 'tab\n'
    return 0
  fi

  if firefox_running; then
    printf 'newwindow\n'
    return 0
  fi

  printf 'cold\n'
  return 0
}

# Open a URL, preferring an already-open browser tab. Asks brotab for the list of
# open tabs; if one matches, activates that tab and focuses Firefox. Otherwise
# opens a new tab/window with xdg-open and still raises Firefox. Always returns 0
# so the picker loop keeps running.
open_or_focus() {
  local url="$1" want match tab_id tab_title

  if [[ -x "$brotab_bin" ]]; then
    want="$(normalize_url "$url")"
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
      "$brotab_bin" activate --focused "$tab_id" >/dev/null 2>&1 || true
      focus_firefox_for_title "$tab_title"
      return 0
    fi
  fi

  case "$(prepare_firefox_for_new_tab)" in
  newwindow)
    open_in_new_firefox_window "$url" "$firefox_workspace"
    ;;
  cold)
    xdg-open "$url" </dev/null >/dev/null 2>&1 &
    disown
    move_firefox_when_up "$firefox_workspace"
    ;;
  *)
    xdg-open "$url" </dev/null >/dev/null 2>&1 &
    disown
    ;;
  esac
  return 0
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
