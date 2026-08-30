#!/usr/bin/env bash
set -euo pipefail

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS_WRAPPER="$DOTS_ROOT/quickshell/dots-shell"
PANELS="system audio network bluetooth power agents updates notifications calendar"

shell_usage() {
  echo "Usage: dots shell <apps|bookmarks|clipboard|hotkeys|system|refresh|panel NAME>"
}

panel_usage() {
  echo "Usage: dots panel <system|audio|network|bluetooth|power|agents|updates|notifications|calendar>"
}

valid_panel() {
  local wanted="$1" panel
  for panel in $PANELS; do
    [ "$wanted" = "$panel" ] && return 0
  done
  return 1
}

require_quickshell() {
  if ! command -v quickshell >/dev/null 2>&1; then
    echo "dots shell: quickshell is not installed" >&2
    exit 1
  fi
  if [ ! -x "$QS_WRAPPER" ]; then
    echo "dots shell: missing executable $QS_WRAPPER" >&2
    exit 1
  fi
}

run_panel() {
  local panel="${1:-}"
  if ! valid_panel "$panel"; then
    panel_usage >&2
    exit 2
  fi
  require_quickshell
  exec "$QS_WRAPPER" panel "$panel"
}

mode="${1:-}"
[ "$#" -gt 0 ] && shift

case "$mode" in
  shell)
    case "${1:-}" in
      help|-h|--help|"")
        shell_usage
        [ -n "${1:-}" ] || exit 2
        ;;
      apps|launcher|bookmarks|clipboard|hotkeys|system|refresh)
        require_quickshell
        exec "$QS_WRAPPER" "$1"
        ;;
      panel)
        shift
        run_panel "${1:-}"
        ;;
      *)
        shell_usage >&2
        exit 2
        ;;
    esac
    ;;
  panel)
    case "${1:-}" in
      help|-h|--help)
        panel_usage
        ;;
      *) run_panel "${1:-}" ;;
    esac
    ;;
  *)
    shell_usage >&2
    exit 2
    ;;
esac
