#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

# Open a URL in the configured browser, preferring an already-open tab
# (focused via bruvtab) over duplicating it. Called directly from kanata's
# `browser` layer bindings — no fzf picker involved.
#
# Usage: open-url.sh <url> [tab-name]

url="${1:?usage: open-url.sh <url> [tab-name]}"
tab_name="${2:-}"

browser_workspace="2"
youtube_workspace="4"

open_or_focus_url "$url" "$browser_workspace" "$youtube_workspace" "$tab_name"
