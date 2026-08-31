#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: dots theme [status|light|dark|toggle]
USAGE
}

if ! command -v darkman >/dev/null 2>&1; then
  echo "dots theme: darkman is not installed" >&2
  exit 1
fi

case "${1:-status}" in
  status|s)
    darkman get
    ;;
  light|l)
    darkman set light
    ;;
  dark|d)
    darkman set dark
    ;;
  toggle|t)
    current="$(darkman get)"
    case "$current" in
      dark) darkman set light ;;
      light) darkman set dark ;;
      *)
        printf 'dots theme: unexpected darkman state: %s\n' "$current" >&2
        exit 1
        ;;
    esac
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
