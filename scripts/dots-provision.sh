#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  cat <<'USAGE'
Usage: dots provision [--dry-run|--yes] [--json] [--machine name] [--profile names]

Opt-in provisioning for a new machine. The dry-run and real command use the
same calculated action list. `dots apply` never installs packages or enables
system prerequisites.
USAGE
  exit 0
  ;;
esac
exec python3 "$ROOT/scripts/dots-machine.py" provision "$@"
