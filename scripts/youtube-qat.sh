#!/usr/bin/env bash

# Launch the YouTube channel search picker as a kitty quick-access panel,
# matching the look of the bookmarks QAT. Bound to a kanata key (apps layer).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  /usr/bin/env bash "$script_dir/youtube.sh" -s
