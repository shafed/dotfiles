#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  echo "Usage: dots show <run> [--json]"
  exit 0
  ;;
esac
exec python3 "$ROOT/scripts/dots-state.py" show "$@"
