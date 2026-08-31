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
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backup_root="$state_home/dotfiles/backups"
backup_run_dir="${DOTS_BACKUP_RUN_DIR:-}"
pending=0
unresolved=0

note_pending() {
  pending=1
  printf 'PENDING %s\n' "$1"
}

backup_path() {
  local source="$1" rel dest stamp

  if [ ! -e "$source" ] && [ ! -L "$source" ]; then
    return 0
  fi

  if [ -z "$backup_run_dir" ]; then
    mkdir -p -m 700 "$backup_root"
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    backup_run_dir="$(mktemp -d "$backup_root/$stamp-XXXXXX")"
  else
    mkdir -p -m 700 "$backup_run_dir"
  fi

  case "$source" in
    "$HOME"/*) rel="${source#"$HOME"/}" ;;
    *) rel="${source#/}" ;;
  esac
  dest="$backup_run_dir/$rel"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    printf '  backup: %s -> %s (already saved)\n' "$source" "$dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a -- "$source" "$dest"
  printf '  backup: %s -> %s\n' "$source" "$dest"
}

waybar_config="$config_home/waybar"
if [ -L "$waybar_config" ]; then
  note_pending "$waybar_config is a retired Waybar symlink"
  if [ "$CHECK_ONLY" -eq 0 ]; then
    backup_path "$waybar_config"
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

darkman_scripts_link="$data_home/darkman"
darkman_scripts_source="$root/darkman/scripts"
if [ -e "$darkman_scripts_link" ] || [ -L "$darkman_scripts_link" ]; then
  if ! [ -L "$darkman_scripts_link" ] ||
    [ "$(readlink -f "$darkman_scripts_link" 2>/dev/null || true)" != "$(readlink -f "$darkman_scripts_source" 2>/dev/null || true)" ]; then
    note_pending "$darkman_scripts_link does not point at $darkman_scripts_source"
    if [ "$CHECK_ONLY" -eq 0 ]; then
      backup_path "$darkman_scripts_link"
      rm -rf "$darkman_scripts_link"
      echo "  removed stale $darkman_scripts_link so dots apply can relink it"
    fi
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
