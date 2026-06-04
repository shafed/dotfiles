#!/usr/bin/env bash

set -euo pipefail

script_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Fuzzy-find installed applications by name and launch the pick. Mirrors the
# look/feel of bookmarks.sh and youtube.sh (same fzf colors).
#
# Usage:
#   apps.sh             # pick an app and launch it
#   apps.sh -r          # rebuild the app cache, then pick
#   apps.sh -h          # this help
#
# Notes:
#   - Reads freedesktop .desktop entries from the standard XDG dirs. Entries
#     marked NoDisplay=true or Hidden=true are skipped (same as menus do).
#   - Launches via gtk-launch so the app's own Exec/Actions handling applies,
#     and detaches with setsid so it survives this QAT panel closing.

fzf_colors_file="$HOME/dotfiles/colorscheme/active/active-fzf-colors.sh"
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

# Render the fzf preview for a single app from its .desktop file: name,
# comment, and the command it runs. Pulled live from the file (cheap, local),
# so no cache fields beyond the path are needed.
# Called as a subprocess by fzf, so it must not depend on the rest of the script.
if [[ "${1:-}" == "--preview" ]]; then
  file="${2:-}"
  [[ -n "$file" && -f "$file" ]] || exit 0

  # First value of a key in the [Desktop Entry] group (ignore localized [xx] keys).
  field() {
    awk -F= -v key="$1" '
      /^\[/ { in_main = ($0 == "[Desktop Entry]") }
      in_main && $1 == key { sub(/^[^=]*=/, ""); print; exit }
    ' "$file"
  }

  name="$(field Name)"
  comment="$(field Comment)"
  exec_line="$(field Exec)"
  categories="$(field Categories)"

  [[ -n "$name" ]] && printf '%s\n\n' "$name"
  [[ -n "$comment" ]] && printf '%s\n\n' "$comment"
  [[ -n "$exec_line" ]] && printf 'Exec: %s\n' "$exec_line"
  [[ -n "$categories" ]] && printf 'Categories: %s\n' "$categories"
  exit 0
fi

usage() {
  sed -n '7,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf is not installed." >&2
  exit 1
fi

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
      type=""; name=""; nodisplay=""; hidden=""
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

# (Re)build the cache when missing or forced with -r.
if [[ "$refresh" == true || ! -s "$cache_file" ]]; then
  build_cache
fi

if [[ ! -s "$cache_file" ]]; then
  echo "No applications found." >&2
  exit 1
fi

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

fzf_args=(
  --height=100%
  --reverse
  --delimiter=$'\t'
  --with-nth=1
  --prompt="Launch app > "
  --header="Enter to launch, Esc to cancel"
  --preview "$script_self --preview {3}"
  --preview-window "right,55%,wrap"
)

source_fzf_colors
if [[ -n "${linkarzu_fzf_colors:-}" ]]; then
  fzf_args+=(--color="$linkarzu_fzf_colors")
fi

switch_to_english
selected="$(sorted_apps | fzf "${fzf_args[@]}")" || exit 0

IFS=$'\t' read -r _name id _path <<<"$selected"
if [[ -z "${id:-}" ]]; then
  echo "Invalid selection: $selected" >&2
  exit 1
fi

# Count this launch so the app rises in next time's ordering.
record_launch "$id"

# gtk-launch wants the desktop-file id without the trailing .desktop.
desktop_id="${id%.desktop}"

# Detach into its own session so the app survives this QAT panel closing the
# instant the script exits (same reasoning as youtube.sh's xdg-open).
if command -v gtk-launch >/dev/null 2>&1; then
  setsid -f gtk-launch "$desktop_id" >/dev/null 2>&1
else
  # Fallback: parse Exec, strip field codes (%u %f %F ...), and run it directly.
  exec_line="$(awk '/^\[Desktop Entry\]/{f=1;next} /^\[/{f=0} f && /^Exec=/{sub(/^Exec=/,"");print;exit}' "$_path")"
  exec_line="$(printf '%s' "$exec_line" | sed 's/%[a-zA-Z]//g')"
  setsid -f bash -c "$exec_line" >/dev/null 2>&1
fi
