#!/usr/bin/env bash
set -u

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/dots-lib.sh
source "$DOTS_ROOT/scripts/dots-lib.sh"

show_logs=1
case "${1:-}" in
  "") ;;
  --no-logs) show_logs=0 ;;
  help|-h|--help)
    echo "Usage: dots debug [--no-logs]"
    exit 0
    ;;
  *)
    echo "Usage: dots debug [--no-logs]" >&2
    exit 2
    ;;
esac

section() { printf '\n== %s ==\n' "$1"; }

version_line() {
  local label="$1"
  shift
  if command -v "$1" >/dev/null 2>&1; then
    local output
    output="$("$@" 2>&1 | head -n 1)"
    printf '%-12s %s\n' "$label" "${output:-unknown}"
  else
    printf '%-12s missing\n' "$label"
  fi
}

service_line() {
  local unit="$1" enabled active
  enabled="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"
  active="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
  printf '%-24s enabled=%-10s active=%s\n' "$unit" "${enabled:-unknown}" "${active:-unknown}"
}

section "repository"
printf 'root         %s\n' "$DOTS_ROOT"
if command -v git >/dev/null 2>&1 && git -C "$DOTS_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'branch       %s\n' "$(git -C "$DOTS_ROOT" branch --show-current 2>/dev/null || true)"
  printf 'commit       %s\n' "$(git -C "$DOTS_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
  if [ -n "$(git -C "$DOTS_ROOT" status --short 2>/dev/null || true)" ]; then
    printf 'worktree     dirty\n'
  else
    printf 'worktree     clean\n'
  fi
fi

section "session"
printf 'date         %s\n' "$(date -Is 2>/dev/null || date)"
printf 'kernel       %s\n' "$(uname -srmo 2>/dev/null || uname -a)"
printf 'session      %s / %s\n' "${XDG_CURRENT_DESKTOP:-unknown}" "${XDG_SESSION_TYPE:-unknown}"
printf 'config       %s\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
printf 'cache        %s\n' "${XDG_CACHE_HOME:-$HOME/.cache}"

section "versions"
version_line Hyprland Hyprland --version
version_line Quickshell quickshell --version
version_line Kanata kanata --version
version_line Darkman darkman --version
version_line Python python3 --version

section "systemd user"
if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  for unit in "${DOTS_CORE_USER_SERVICES[@]}"; do
    service_line "$unit"
  done
else
  echo "systemd user manager unavailable"
fi

section "doctor summary"
doctor_tmp="$(mktemp)"
if "$DOTS_ROOT/dots" doctor >"$doctor_tmp" 2>&1; then
  doctor_state="ok"
else
  doctor_state="issues"
fi
printf 'state        %s\n' "$doctor_state"
grep -E '^(  FAIL|  WARN|Doctor:)' "$doctor_tmp" || true
rm -f "$doctor_tmp"

if [ "$show_logs" -eq 1 ]; then
  section "quickshell journal"
  if command -v journalctl >/dev/null 2>&1; then
    journalctl --user -u quickshell.service -n 30 --no-pager -o cat 2>&1 || true
  else
    echo "journalctl unavailable"
  fi
fi
