#!/usr/bin/env bash

set -o pipefail

output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
[ -n "$output" ] || exit 1

grim -o "$output" - | wl-copy --type image/png
