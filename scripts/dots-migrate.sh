#!/usr/bin/env bash
set -euo pipefail

CHECK_ONLY=0
case "${1:-}" in
  "") ;;
  --check) CHECK_ONLY=1 ;;
  help|-h|--help)
    echo "Usage: dots migrate [--check]"
    exit 0
    ;;
  *)
    echo "Usage: dots migrate [--check]" >&2
    exit 2
    ;;
esac

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
pending=0
unresolved=0

note_pending() {
  pending=1
  printf 'PENDING %s\n' "$1"
}

waybar_config="$config_home/waybar"
if [ -L "$waybar_config" ]; then
  note_pending "$waybar_config is a retired Waybar symlink"
  if [ "$CHECK_ONLY" -eq 0 ]; then
    rm "$waybar_config"
    echo "  removed retired Waybar symlink"
  fi
elif [ -e "$waybar_config" ]; then
  note_pending "$waybar_config exists, but Waybar is retired"
  if [ "$CHECK_ONLY" -eq 0 ]; then
    echo "  kept unmanaged Waybar config; remove or archive it manually" >&2
    unresolved=1
  fi
fi

waybar_cache="$cache_home/waybar"
if [ -e "$waybar_cache" ] || [ -L "$waybar_cache" ]; then
  note_pending "$waybar_cache is stale Waybar cache"
  if [ "$CHECK_ONLY" -eq 0 ]; then
    rm -rf "$waybar_cache"
    echo "  removed stale Waybar cache"
  fi
fi

if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  enabled_state="$(systemctl --user is-enabled waybar.service 2>/dev/null || true)"
  active_state="$(systemctl --user is-active waybar.service 2>/dev/null || true)"
  if [ "$enabled_state" = "enabled" ] || [ "$active_state" = "active" ]; then
    note_pending "waybar.service is still enabled or active"
    if [ "$CHECK_ONLY" -eq 0 ]; then
      systemctl --user disable --now waybar.service >/dev/null 2>&1 || true
      echo "  disabled Waybar user service"
    fi
  fi
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  if [ "$pending" -eq 0 ]; then
    echo "migrations: clean"
    exit 0
  fi
  exit 1
fi

if [ "$unresolved" -ne 0 ]; then
  exit 1
fi

if [ "$pending" -eq 0 ]; then
  echo "No migrations needed."
else
  echo "Migrations applied."
fi
