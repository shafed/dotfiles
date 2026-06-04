#!/usr/bin/env bash

# Launch the installed-applications picker as a kitty quick-access panel,
# matching the look of the YouTube/bookmarks QATs. Bound to a kanata key
# (apps layer).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# NOT single-instance: apps.sh is one-shot (pick -> launch -> exit). With
# --single-instance, a second trigger opens a new window inside the still-alive
# panel instance, and a window could survive its script exiting — that was the
# intermittent "fzf stays open after launch". A fresh panel per trigger owns its
# own process and tears down deterministically when apps.sh returns.
# Give the panel its own remote-control socket so apps.sh can close this exact
# window after launching (KITTY_LISTEN_ON is exported to the child). Without an
# explicit --listen-on the panel may not expose one, and the close would silently
# no-op — leaving fzf on screen after launch.
panel_socket="unix:/tmp/kitty-apps-panel-$$"
exec kitty +kitten panel \
  --app-id=kitty-quick-access \
  --layer=overlay \
  --edge=center \
  --lines=25 \
  --columns=90 \
  --focus-policy=exclusive \
  --override=background_opacity=0.95 \
  --override=allow_remote_control=yes \
  --listen-on="$panel_socket" \
  /usr/bin/env bash "$script_dir/apps.sh"
