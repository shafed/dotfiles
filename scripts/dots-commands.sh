#!/usr/bin/env bash
set -euo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/dots-lib.sh
source "$DOTS_ROOT/scripts/dots-lib.sh"

case "${1:-}" in
  "") dots_print_commands ;;
  --json) dots_print_commands_json ;;
  help|-h|--help)
    echo "Usage: dots commands [--json]"
    ;;
  *)
    echo "Usage: dots commands [--json]" >&2
    exit 2
    ;;
esac
