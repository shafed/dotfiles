#!/usr/bin/env bash

# Launch the installed-applications picker as a kitty quick-access panel,
# matching the look of the YouTube/bookmarks QATs. Bound to a kanata key
# (apps layer).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec kitty +kitten panel \
  --single-instance \
  --instance-group=apps \
  --app-id=kitty-quick-access \
  --layer=overlay \
  --edge=center \
  --lines=25 \
  --columns=90 \
  --focus-policy=exclusive \
  --override=background_opacity=0.95 \
  /usr/bin/env bash "$script_dir/apps.sh"
