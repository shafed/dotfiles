#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  cat <<'USAGE'
Usage: dots doctor [--json] [--machine name] [--profile names]

Check packages, prerequisites, services, generated state and profile drift.
USAGE
  exit 0
  ;;
esac
exec python3 "$ROOT/scripts/dots-state.py" doctor "$@"
