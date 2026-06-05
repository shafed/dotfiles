#!/usr/bin/env bash

set -euo pipefail

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Fuzzy-find installed applications by name and launch the pick. Mirrors the
# look/feel AND mechanism of bookmarks.sh: runs inside a long-lived kitty
# quick-access panel that is toggled via the remote-control socket, so it
# overlays the screen the same way and opens instantly (the fzf process stays
# alive between triggers instead of cold-starting a new panel each time).
#
# Usage:
#   apps.sh             # launch (or toggle) the picker QAT
#   apps.sh -r          # rebuild the app cache, then launch the picker
#   apps.sh --pick      # internal: run the picker loop inside the QAT panel
#   apps.sh -h          # this help
#
# Notes:
#   - Reads freedesktop .desktop entries from the standard XDG dirs. Entries
#     marked NoDisplay=true or Hidden=true are skipped (same as menus do).
#   - Launches via gtk-launch so the app's own Exec/Actions handling applies,
#     and detaches with setsid so it survives the panel hiding.

fzf_colors_file="$HOME/dotfiles/colorscheme/active/active-fzf-colors.sh"
qat_config="$HOME/dotfiles/kitty/quick-access-terminal-center.conf"
kitty_bin="$(command -v kitty || echo /usr/bin/kitty)"
apps_group="apps"
cache_dir="$HOME/.cache/apps-fzf"
cache_file="$cache_dir/apps.tsv"
# Launch tally (desktop-file-id<tab>count). Kept apart from the catalog cache so
# usage ordering survives a -r rebuild and updates without re-scanning .desktop.
usage_file="$cache_dir/usage.tsv"
refresh=false
tab=$'\t'

# Directories that hold .desktop entries, lowest to highest priority. Later
# dirs win on duplicate desktop-file IDs (user overrides system).
app_dirs=(
  /usr/share/applications
  /usr/local/share/applications
  "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
)

usage() {
  sed -n '8,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is not installed." >&2
  exit 1
fi

# Pull the long-only --pick flag out before getopts, which only understands
# short options and would choke on "--". --pick means "run the picker loop
# inside the QAT panel"; without it we are the launcher that spawns the panel.
pick_mode=false
list_mode=""
args=()
for arg in "$@"; do
  case "$arg" in
  --pick) pick_mode=true ;;
  --recent) list_mode="recent" ;;
  --all) list_mode="all" ;;
  *) args+=("$arg") ;;
  esac
done
set -- "${args[@]+"${args[@]}"}"

while getopts ":rh" opt; do
  case "$opt" in
  r) refresh=true ;;
  h) usage 0 ;;
  \?)
    echo "Unknown option: -$OPTARG" >&2
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

# Force the keyboard to English so fzf search matches latin app names even when
# the active layout is Russian. Index 0 is "us" in hyprland.conf's kb_layout
# (us,ru). Best-effort: silently no-op outside Hyprland.
switch_to_english() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl switchxkblayout all 0 >/dev/null 2>&1 || true
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

# Toggle (hide/show) the apps QAT panel. Because the panel is single-instance
# per instance-group, sending the same launch command flips its visibility
# instead of spawning a second panel — this is what makes re-triggers instant.
toggle_apps_qat() {
  local sock

  sock="$(main_kitty_socket)" || return 0
  "$kitty_bin" @ --to "unix:${sock}" \
    action launch --type=background kitten quick-access-terminal \
    --config "$qat_config" \
    --instance-group "$apps_group" >/dev/null 2>&1 || true
}

launch_apps_qat() {
  local sock pick_args

  # Force English here, in the launcher, because this runs on EVERY hotkey press
  # (kanata -> apps.sh). When the panel already exists, kitty merely toggles its
  # visibility and the picker loop's own switch_to_english never re-runs — so the
  # in-loop call only ever fixes the layout on the very first cold start. Doing it
  # here guarantees the layout flips to us each time the panel is shown.
  switch_to_english

  # Forward -r so a "rebuild then pick" still rebuilds inside the panel, where
  # the picker loop actually reads the cache.
  pick_args=(--pick)
  [[ "$refresh" == true ]] && pick_args+=(-r)

  sock="$(main_kitty_socket)" || {
    echo "No main kitty socket found."
    exit 1
  }

  "$kitty_bin" @ --to "unix:${sock}" \
    action launch --type=background kitten quick-access-terminal \
    --config "$qat_config" \
    --instance-group "$apps_group" \
    /usr/bin/env bash "$script_path" "${pick_args[@]}"
}

# Build "Name<tab>desktop-file-id<tab>path" rows from all .desktop entries,
# skipping NoDisplay/Hidden ones and de-duplicating by id so a user override
# shadows the system copy.
build_cache() {
  mkdir -p "$cache_dir"
  local dir file id name nodisplay hidden type
  : >"$cache_file.tmp"

  for dir in "${app_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    for file in "$dir"/*.desktop; do
      [[ -f "$file" ]] || continue
      id="${file##*/}"

      # Read only the [Desktop Entry] group; localized [xx] keys are ignored.
      type=""
      name=""
      nodisplay=""
      hidden=""
      while IFS= read -r line; do
        case "$line" in
        Type=*) type="${line#Type=}" ;;
        Name=*) name="${line#Name=}" ;;
        NoDisplay=*) nodisplay="${line#NoDisplay=}" ;;
        Hidden=*) hidden="${line#Hidden=}" ;;
        esac
      done < <(awk '/^\[Desktop Entry\]/{f=1;next} /^\[/{f=0} f' "$file")

      [[ "$type" == "Application" ]] || continue
      [[ "$nodisplay" == "true" ]] && continue
      [[ "$hidden" == "true" ]] && continue
      [[ -n "$name" ]] || continue

      printf '%s\t%s\t%s\n' "$name" "$id" "$file" >>"$cache_file.tmp"
    done
  done

  # Keep the last row per desktop-file id (user dirs come last, so they win),
  # then sort by display name for a stable, readable list.
  awk -F'\t' '{ rows[$2] = $0 } END { for (k in rows) print rows[k] }' "$cache_file.tmp" |
    sort -f -t"$tab" -k1,1 >"$cache_file"
  rm -f "$cache_file.tmp"
}

# Feed the catalog to fzf sorted by launch count (desc), then name (asc) so the
# most-used apps sit at the top and ties stay alphabetical. Counts are joined
# from usage_file by desktop-file id; unseen apps get 0 and fall to the bottom.
sorted_apps() {
  awk -F'\t' -v usage="$usage_file" '
    BEGIN {
      while ((getline line < usage) > 0) {
        split(line, u, "\t")
        if (u[1] != "") count[u[1]] = u[2] + 0
      }
    }
    { c = (($2 in count) ? count[$2] : 0); print c "\t" $0 }
  ' "$cache_file" |
    sort -t"$tab" -k1,1nr -k2,2f |
    cut -f2-
}

# Like sorted_apps, but keep only apps that have actually been launched before
# (a positive count in usage_file). Shown when the query is empty so the picker
# opens to "recently/most used" instead of the whole catalog. Typing anything
# switches back to the full list (see the change:reload bind below).
recent_apps() {
  awk -F'\t' -v usage="$usage_file" '
    BEGIN {
      while ((getline line < usage) > 0) {
        split(line, u, "\t")
        if (u[1] != "") count[u[1]] = u[2] + 0
      }
    }
    (($2 in count) && count[$2] > 0) { print count[$2] "\t" $0 }
  ' "$cache_file" |
    sort -t"$tab" -k1,1nr -k2,2f |
    cut -f2-
}

# Bump the launch count for a desktop-file id. Rewrites usage_file atomically.
record_launch() {
  local target="$1" tmp
  mkdir -p "$cache_dir"
  # Ensure the file exists; awk skips its END block if its only input is missing,
  # which would drop the first-ever launch of an app.
  [[ -f "$usage_file" ]] || : >"$usage_file"
  tmp="$(mktemp "$cache_dir/usage.XXXXXX")" || return 0
  awk -F'\t' -v id="$target" '
    $1 == id { print $1 "\t" ($2 + 1); seen = 1; next }
    NF { print }
    END { if (!seen) print id "\t" 1 }
  ' "$usage_file" >"$tmp"
  mv "$tmp" "$usage_file"
}

# Launch the picked app, detached into its own session so it survives the panel
# hiding. We run the parsed Exec= line directly rather than leaning on
# gtk-launch: gtk-launch (and gio launch) silently no-op on DBusActivatable=true
# entries whose desktop-file id is not a valid D-Bus name — e.g. Telegram's
# hashed id org.telegram.desktop._<hash>.desktop — returning 0 while launching
# nothing. Parsing Exec= works for every entry regardless of id/DBusActivatable.
# gtk-launch stays as the fallback for the rare entry that has no Exec= line.
launch_app() {
  local file="$1" id="$2" exec_line
  exec_line="$(awk '/^\[Desktop Entry\]/{f=1;next} /^\[/{f=0} f && /^Exec=/{sub(/^Exec=/,"");print;exit}' "$file")"

  if [[ -n "$exec_line" ]]; then
    # Strip freedesktop field codes (%u %f %F %U %i %c %k ...) before running.
    exec_line="$(printf '%s' "$exec_line" | sed 's/%[a-zA-Z]//g')"
    setsid -f bash -c "$exec_line" >/dev/null 2>&1
  elif command -v gtk-launch >/dev/null 2>&1; then
    # gtk-launch wants the id without the trailing .desktop.
    setsid -f gtk-launch "${id%.desktop}" >/dev/null 2>&1
  fi
}

# Internal list providers invoked by fzf's reload binds. They just print rows
# and exit; kept lightweight so reloading on every keystroke stays snappy. The
# cache is guaranteed to exist by the time fzf runs (the --pick branch builds it
# before starting fzf).
if [[ "$list_mode" == "recent" ]]; then
  recent_apps
  exit 0
fi
if [[ "$list_mode" == "all" ]]; then
  sorted_apps
  exit 0
fi

# The picker loop. Runs inside the QAT panel (apps.sh --pick). Keeps the process
# alive after every action so kitty only toggles the panel's visibility on the
# next trigger instead of cold-starting it — same trick as bookmarks.sh.
if [[ "$pick_mode" == true ]]; then
  # (Re)build the cache when missing or forced with -r.
  if [[ "$refresh" == true || ! -s "$cache_file" ]]; then
    build_cache
  fi

  if [[ ! -s "$cache_file" ]]; then
    echo "No applications found."
    read -r -p "Press enter to close. "
    exit 1
  fi

  # Empty query -> recently/most-used only; any typed query -> full catalog.
  # fzf re-runs these subcommands of ourself on start and on every keystroke.
  printf -v quoted_self '%q' "$script_path"
  list_reload="if [[ -z {q} ]]; then $quoted_self --recent; else $quoted_self --all; fi"

  fzf_args=(
    --height=100%
    --reverse
    --delimiter=$'\t'
    --with-nth=1
    --prompt="Launch app > "
    --header="Empty = recent, type to search all"
    --bind "start:reload($list_reload)"
    --bind "change:reload($list_reload)"
  )

  source_fzf_colors
  if [[ -n "${linkarzu_fzf_colors:-}" ]]; then
    fzf_args+=(--color="$linkarzu_fzf_colors")
  fi

  while true; do
    switch_to_english
    # Esc makes fzf exit non-zero. Treat it as "hide and rearm" so the next
    # keypress shows an already-running picker instead of starting from cold.
    # The list itself comes from the reload binds, so feed fzf an empty stdin.
    if ! selected=$(: | fzf "${fzf_args[@]}"); then
      toggle_apps_qat
      continue
    fi

    IFS=$'\t' read -r _name id _path <<<"$selected"

    if [[ -z "${id:-}" ]]; then
      echo "Invalid selection: $selected"
      read -r -p "Press enter to continue. "
      toggle_apps_qat
      continue
    fi

    # Count this launch so the app rises in next time's ordering.
    record_launch "$id"

    # Hide the panel first, then launch the app detached (same reasoning as
    # bookmarks.sh's xdg-open: it must outlive this panel hiding).
    toggle_apps_qat
    launch_app "$_path" "$id"
  done
fi

launch_apps_qat
