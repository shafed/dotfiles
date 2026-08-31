#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
""|help|-h|--help)
  cat <<'USAGE'
Usage: dots rollback <run>

Restore only files, symlinks and generated outputs owned by the selected run.
Rollback refuses to overwrite paths that changed after that run.
USAGE
  [ -n "${1:-}" ] && exit 0 || exit 2
  ;;
esac
exec python3 "$ROOT/scripts/dots-state.py" rollback "$@"
