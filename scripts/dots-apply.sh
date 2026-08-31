#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTS_ROOT="$ROOT"
# shellcheck source=scripts/dots-lib.sh
source "$ROOT/scripts/dots-lib.sh"

usage() {
  cat <<'USAGE'
Usage: dots apply [--check|--links-only]

Bring this machine in line with the current dotfiles checkout.
  --check       Only report required commands and validate link sources
  --links-only  Only install managed links/wrappers (legacy bootstrap --link)
USAGE
}

check_requirements() {
  echo "== required commands =="
  local entry cmd pkg missing=0
  for entry in "${REQUIRED_PKGS[@]}"; do
    cmd="${entry%%:*}"
    pkg="${entry#*:}"
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '  ok      %s\n' "$cmd"
    else
      printf '  MISSING %-18s package: %s\n' "$cmd" "$pkg"
      missing=$((missing + 1))
    fi
  done
  if [ "$missing" -eq 0 ]; then
    echo "All required commands found."
  else
    echo "$missing required command(s) are missing; links can still be applied, and dots doctor will remain non-zero."
  fi
}

check_sources() {
  echo "== managed sources =="
  local missing=0 name src
  for name in "${CONFIG_DIRS[@]}"; do
    if [ ! -d "$ROOT/$name" ]; then
      echo "  MISSING $name/" >&2
      missing=1
    fi
  done
  for src in "${LINK_FILES[@]}"; do
    if [ ! -e "$ROOT/$src" ]; then
      echo "  MISSING $src" >&2
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    echo "Managed sources are incomplete; refusing to apply links." >&2
    return 1
  fi
  echo "  all sources present"
}

same_link() {
  local source="$1" dest="$2"
  [ -L "$dest" ] || return 1
  [ "$(readlink -f "$dest" 2>/dev/null || true)" = "$(readlink -f "$source" 2>/dev/null || true)" ]
}

install_link() {
  local source="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if same_link "$source" "$dest"; then
    printf '  ok      %s\n' "$dest"
    return 0
  fi
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    printf '  REFUSE  %s exists and is not a symlink; move or archive it first\n' "$dest" >&2
    return 1
  fi
  ln -sfnT "$source" "$dest"
  printf '  linked  %s -> %s\n' "$dest" "$source"
}

install_links() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local name spec source_rel dest failed=0

  echo "== managed links =="
  mkdir -p "$config_home"
  for name in "${CONFIG_DIRS[@]}"; do
    install_link "$ROOT/$name" "$config_home/$name" || failed=1
  done
  for spec in "${DOTS_MANAGED_LINKS[@]}"; do
    source_rel="${spec%%|*}"
    dest="${spec#*|}"
    install_link "$ROOT/$source_rel" "$dest" || failed=1
  done

  if [ "$failed" -ne 0 ]; then
    echo "One or more unmanaged paths blocked apply; no existing real file/directory was removed." >&2
    return 1
  fi

  echo "== managed wrappers =="
  mkdir -p "$HOME/.local/bin"
  cat >"$HOME/.local/bin/sudo" <<EOF_WRAPPER
#!/usr/bin/env bash
exec "$ROOT/scripts/sudo-notify.sh" "\$@"
EOF_WRAPPER
  chmod +x "$HOME/.local/bin/sudo"
  echo "  wrote   $HOME/.local/bin/sudo"

  cat >"$HOME/.local/bin/sioyek" <<EOF_WRAPPER
#!/usr/bin/env bash
exec env -u LIBGL_ALWAYS_SOFTWARE QT_QPA_PLATFORM=xcb /usr/bin/sioyek "\$@"
EOF_WRAPPER
  chmod +x "$HOME/.local/bin/sioyek"
  echo "  wrote   $HOME/.local/bin/sioyek"

  echo "== Helium Gruvbox theme =="
  python3 "$ROOT/helium/apply-gruvbox-theme.py"

  echo "== CopyQ config =="
  python3 "$ROOT/scripts/copyq-apply-theme.py"

  if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    if systemctl --user list-unit-files dunst.service >/dev/null 2>&1; then
      systemctl --user mask --now dunst.service >/dev/null 2>&1 || true
      echo "  masked  dunst.service"
    fi
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
}

refresh_runtime() {
  local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  local runtime="$cache_home/dots-shell/quickshell"
  local unit

  echo "== derived state =="
  rm -rf "$runtime"
  echo "  cleared generated Quickshell runtime"

  if ! command -v systemctl >/dev/null 2>&1 || ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "  systemd user manager unavailable; services will use the new state on their next start"
    return 0
  fi

  systemctl --user daemon-reload
  for unit in "${DOTS_CORE_USER_SERVICES[@]}"; do
    systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true
    if systemctl --user try-restart "$unit" >/dev/null 2>&1; then
      echo "  refreshed $unit if it was running"
    else
      echo "  WARN    could not refresh $unit; dots doctor will report its final state" >&2
    fi
  done
}

mode="full"
case "${1:-}" in
  "") ;;
  --check) mode="check" ;;
  --links-only|--link) mode="links" ;;
  help|-h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ "$mode" != "links" ]; then
  check_requirements
fi
check_sources

if [ "$mode" = "check" ]; then
  exit 0
fi

install_links

if [ "$mode" = "links" ]; then
  echo "Apply links: done."
  exit 0
fi

echo "== migrations =="
"$ROOT/scripts/dots-migrate.sh"
refresh_runtime

echo "== doctor =="
exec "$ROOT/scripts/dots-doctor.sh"
