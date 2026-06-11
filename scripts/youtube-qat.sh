#!/usr/bin/env bash

# Launch the YouTube channel search picker as a kitty quick-access panel,
# matching the look of the bookmarks QAT. Bound to a kanata key (apps layer).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

# Force English layout each time the panel is shown. The single-instance panel
# only re-runs youtube.sh's own switch_to_english on a cold start — on a toggle
# kitty merely re-shows the existing process, so doing it here guarantees the
# layout flips to "us" every time. Best-effort: no-op outside Hyprland.
switch_to_english

exec kitty +kitten panel \
  --single-instance \
  --instance-group=youtube \
  --app-id=kitty-quick-access \
  --layer=overlay \
  --edge=center \
  --lines=25 \
  --columns=90 \
  --focus-policy=exclusive \
  --override=background_opacity=0.95 \
  --override=close_on_child_death=yes \
  /usr/bin/env bash "$script_dir/youtube.sh" -s
