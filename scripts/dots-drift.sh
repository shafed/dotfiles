#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  cat <<'USAGE'
Usage: dots drift [--json] [--machine name] [--profile names]

Compare the whole machine with the selected manifest. Managed drift and missing
required packages affect the exit status; extra explicitly installed packages
and unexpected local user services are informational only.
USAGE
  exit 0
  ;;
esac
exec python3 "$ROOT/scripts/dots-machine.py" drift "$@"
