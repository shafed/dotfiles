#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# This is a one-time profile migration, not a solar-state generator. Chromium's
# native User Color theme follows darkman's XDG portal signal after activation.
python3 "$ROOT/helium/apply-gruvbox-theme.py"
