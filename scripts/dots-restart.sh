#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: dots restart <quickshell|kanata|darkman|all>"
}

require_user_systemd() {
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "dots restart: systemctl is unavailable" >&2
    exit 1
  fi
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "dots restart: systemd user manager is unavailable" >&2
    exit 1
  fi
}

restart_one() {
  local name="$1" unit
  case "$name" in
    quickshell) unit="quickshell.service" ;;
    kanata) unit="kanata.service" ;;
    darkman) unit="darkman.service" ;;
    *)
      usage >&2
      return 2
      ;;
  esac
  echo "Restarting $unit"
  systemctl --user restart "$unit"
}

case "${1:-}" in
  help|-h|--help)
    usage
    exit 0
    ;;
  quickshell|kanata|darkman)
    require_user_systemd
    restart_one "$1"
    ;;
  all)
    require_user_systemd
    restart_one quickshell
    restart_one kanata
    restart_one darkman
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
