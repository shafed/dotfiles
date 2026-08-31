#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  cat <<'USAGE'
Usage: dots stage [ref] [--json] [--machine name] [--profile names]

Check a candidate Git ref in a detached temporary worktree and temporary HOME.
It runs `dots check` and `dots plan` there and never switches active ~/.config
links. Activation remains an explicit later `dots apply` decision.
USAGE
  exit 0
  ;;
esac
exec python3 "$ROOT/scripts/dots-machine.py" stage "$@"
