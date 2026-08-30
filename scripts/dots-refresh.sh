#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: dots refresh <quickshell|systemd|all>"
}

require_user_systemd() {
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "dots refresh: systemctl is unavailable" >&2
    exit 1
  fi
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "dots refresh: systemd user manager is unavailable" >&2
    exit 1
  fi
}

refresh_systemd() {
  echo "Reloading systemd user units"
  systemctl --user daemon-reload
}

refresh_quickshell() {
  local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  local runtime="$cache_home/dots-shell/quickshell"
  echo "Rebuilding Quickshell runtime on restart"
  rm -rf "$runtime"
  systemctl --user reset-failed quickshell.service >/dev/null 2>&1 || true
  systemctl --user restart quickshell.service
}

case "${1:-}" in
  help|-h|--help)
    usage
    exit 0
    ;;
  quickshell)
    require_user_systemd
    refresh_quickshell
    ;;
  systemd)
    require_user_systemd
    refresh_systemd
    ;;
  all)
    require_user_systemd
    refresh_systemd
    refresh_quickshell
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
