#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  cat <<'USAGE'
Usage: dots provision [--check|--yes] [--machine name] [--profile names]

Opt-in provisioning for a new machine. Installs missing profile packages and
enables declared system prerequisites; normal `dots apply` never installs them.
Currently only the Arch Linux backend is implemented.
USAGE
  exit 0
  ;;
esac
if [ ! -e /etc/arch-release ]; then
  echo "dots provision: only the Arch Linux backend is implemented" >&2
  exit 2
fi
exec python3 "$ROOT/scripts/dots-state.py" provision "$@"
