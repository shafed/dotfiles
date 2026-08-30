#!/usr/bin/env bash
set -u

DOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/dots-lib.sh
source "$DOTS_ROOT/scripts/dots-lib.sh"

case "${1:-}" in
  "") ;;
  help|-h|--help)
    echo "Usage: dots doctor"
    exit 0
    ;;
  *)
    echo "Usage: dots doctor" >&2
    exit 2
    ;;
esac

errors=0
warnings=0

section() { printf '\n== %s ==\n' "$1"; }
ok() { printf '  ok    %s\n' "$1"; }
warn() { printf '  WARN  %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; errors=$((errors + 1)); }

same_link() {
  local source="$1" dest="$2"
  [ -L "$dest" ] || return 1
  [ "$(readlink -f "$dest" 2>/dev/null || true)" = "$(readlink -f "$source" 2>/dev/null || true)" ]
}

section "symlinks"
for name in "${CONFIG_DIRS[@]}"; do
  source_path="$DOTS_ROOT/$name"
  dest="${XDG_CONFIG_HOME:-$HOME/.config}/$name"
  if same_link "$source_path" "$dest"; then
    ok "$dest"
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    fail "$dest does not point to $source_path"
  else
    fail "$dest is missing"
  fi
done

for spec in "${DOTS_MANAGED_LINKS[@]}"; do
  source_rel="${spec%%|*}"
  dest="${spec#*|}"
  source_path="$DOTS_ROOT/$source_rel"
  if same_link "$source_path" "$dest"; then
    ok "$dest"
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    fail "$dest does not point to $source_path"
  else
    fail "$dest is missing"
  fi
done

for wrapper in sudo sioyek; do
  wrapper_path="$HOME/.local/bin/$wrapper"
  if [ -x "$wrapper_path" ]; then
    ok "$wrapper_path"
  else
    fail "$wrapper_path is missing or not executable"
  fi
done

section "packages"
for entry in "${REQUIRED_PKGS[@]}"; do
  cmd="${entry%%:*}"
  pkg="${entry#*:}"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd"
  else
    fail "$cmd missing (package: $pkg)"
  fi
done
for entry in "${OPTIONAL_PKGS[@]}"; do
  cmd="${entry%%:*}"
  pkg="${entry#*:}"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd (optional)"
  else
    warn "$cmd missing (optional: $pkg)"
  fi
done

section "systemd user"
if ! command -v systemctl >/dev/null 2>&1; then
  warn "systemctl unavailable; user services not checked"
elif ! systemctl --user show-environment >/dev/null 2>&1; then
  warn "systemd user manager is unavailable; service runtime state not checked"
else
  for unit in "${DOTS_CORE_USER_SERVICES[@]}"; do
    if [ ! -e "$DOTS_ROOT/systemd/user/$unit" ]; then
      fail "tracked unit missing: systemd/user/$unit"
      continue
    fi
    state="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"
    case "$state" in
      enabled|static|indirect) ok "$unit enabled ($state)" ;;
      *) fail "$unit is not enabled (state: ${state:-unknown})" ;;
    esac
  done

  dunst_state="$(systemctl --user is-enabled dunst.service 2>/dev/null || true)"
  if [ "$dunst_state" = "masked" ]; then
    ok "dunst.service masked for Quickshell notifications"
  else
    fail "dunst.service is not masked (state: ${dunst_state:-unknown})"
  fi

  graphical_state="$(systemctl --user is-active graphical-session.target 2>/dev/null || true)"
  if [ "$graphical_state" = "active" ]; then
    for unit in quickshell.service kanata.service; do
      state="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
      if [ "$state" = "active" ]; then
        ok "$unit active"
      else
        fail "$unit is $state while graphical-session.target is active"
      fi
    done
  else
    warn "graphical-session.target is not active; graphical services not required to be running"
  fi

  darkman_state="$(systemctl --user is-active darkman.service 2>/dev/null || true)"
  if [ "$darkman_state" = "active" ]; then
    ok "darkman.service active"
  else
    warn "darkman.service is $darkman_state"
  fi
fi

section "stale config and cache"
if [ -e "$DOTS_ROOT/waybar/config.jsonc" ] || [ -L "$DOTS_ROOT/waybar/config.jsonc" ]; then
  fail "retired Waybar runtime config is still tracked: waybar/config.jsonc"
else
  ok "retired Waybar runtime config is not tracked"
fi

if command -v pgrep >/dev/null 2>&1 && pgrep -x waybar >/dev/null 2>&1; then
  fail "Waybar is still running; Quickshell owns the bar"
else
  ok "Waybar is not running"
fi

cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
qs_cache="$cache_home/dots-shell/quickshell"
if [ -d "$qs_cache" ] && ! same_link "$DOTS_ROOT/quickshell" "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"; then
  warn "$qs_cache exists without the expected Quickshell config link"
elif [ -f "$qs_cache/shell.qml" ]; then
  if find "$DOTS_ROOT/quickshell" -type f \( -name '*.qml' -o -name '*.py' -o -name '*.sh' \) -newer "$qs_cache/shell.qml" -print -quit | grep -q .; then
    warn "generated Quickshell cache is older than tracked sources; run: dots refresh quickshell"
  else
    ok "generated Quickshell cache is current enough"
  fi
else
  ok "no stale generated Quickshell cache detected"
fi

section "migrations"
if "$DOTS_ROOT/scripts/dots-migrate.sh" --check; then
  ok "no pending migrations"
else
  fail "pending migrations; run: dots migrate"
fi

printf '\nDoctor: %d error(s), %d warning(s).\n' "$errors" "$warnings"
[ "$errors" -eq 0 ]
