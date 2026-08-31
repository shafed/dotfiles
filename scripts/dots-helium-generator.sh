#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Build/update the stable exact theme directory and persistent Helium launch
# flags. The darkman hook handles later light/dark transitions.
python3 "$ROOT/helium/apply-gruvbox-theme.py"
