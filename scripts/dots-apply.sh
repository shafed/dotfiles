#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  cat <<'USAGE'
Usage: dots apply [--check|--links-only] [--machine name] [--profile names]

Bring this machine in line with the selected profile.
  --check       Show the plan only; do not change the machine
  --links-only  Apply managed links/files/generators, but skip migrations/refresh/doctor
  --machine     Select machines/<name>.toml instead of hostname/default
  --profile     Comma-separated profile override for testing
USAGE
  exit 0
  ;;
esac
exec python3 "$ROOT/scripts/dots-state.py" apply "$@"
