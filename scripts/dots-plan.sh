#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  cat <<'USAGE'
Usage: dots plan [--json] [--machine name] [--profile names]

Show drift from the selected desired state without changing the machine.
USAGE
  exit 0
  ;;
esac
export DOTS_REAL_HOME="${DOTS_REAL_HOME:-$HOME}"
export DOTS_REAL_XDG_DATA_HOME="${DOTS_REAL_XDG_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}}"
exec python3 "$ROOT/scripts/dots-state.py" plan "$@"
