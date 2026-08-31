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
exec python3 "$ROOT/scripts/dots-state.py" plan "$@"
