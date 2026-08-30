#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/dots-lib.sh
source "$ROOT/scripts/dots-lib.sh"
REAL_PYTHON="$(command -v python3)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fake_bin="$tmp/bin"
mkdir -p "$fake_bin"
export DOTS_TEST_LOG="$tmp/calls.log"
: >"$DOTS_TEST_LOG"

for entry in "${REQUIRED_PKGS[@]}"; do
  cmd="${entry%%:*}"
  if [ "$cmd" = "darkman" ] || [ "$cmd" = "quickshell" ]; then
    continue
  fi
  cat > "$fake_bin/$cmd" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$fake_bin/$cmd"
done

cat > "$fake_bin/darkman" <<'SH'
#!/usr/bin/env bash
case "${1:-get}" in
  get) echo dark ;;
  set) exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$fake_bin/darkman"

cat > "$fake_bin/quickshell" <<'SH'
#!/usr/bin/env bash
printf 'quickshell %s\n' "$*" >>"${DOTS_TEST_LOG:-/dev/null}"
exit 0
SH
chmod +x "$fake_bin/quickshell"

cat > "$fake_bin/systemctl" <<'SH'
#!/usr/bin/env bash
args="$*"
printf 'systemctl %s\n' "$args" >>"${DOTS_TEST_LOG:-/dev/null}"
case "$args" in
  "--user show-environment") exit 0 ;;
  "--user is-enabled dunst.service") echo masked; exit 0 ;;
  "--user is-enabled waybar.service") echo disabled; exit 1 ;;
  "--user is-active waybar.service") echo inactive; exit 3 ;;
  "--user is-enabled quickshell.service"|"--user is-enabled kanata.service"|"--user is-enabled darkman.service") echo enabled; exit 0 ;;
  "--user is-active graphical-session.target"|"--user is-active quickshell.service"|"--user is-active kanata.service"|"--user is-active darkman.service") echo active; exit 0 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$fake_bin/systemctl"

export PATH="$fake_bin:$PATH"

"$ROOT/dots" help >"$tmp/help.out"
grep -q '^  apply' "$tmp/help.out"
grep -q '^  doctor' "$tmp/help.out"
"$ROOT/dots" help apply >"$tmp/apply-help.out"
grep -q '^Usage: dots apply' "$tmp/apply-help.out"
"$ROOT/dots" help restart >"$tmp/restart-help.out"
grep -q '^Usage: dots restart' "$tmp/restart-help.out"
"$ROOT/dots" commands >"$tmp/commands.out"
grep -q '^  apply' "$tmp/commands.out"
grep -q '^  restart' "$tmp/commands.out"
"$ROOT/dots" commands --json >"$tmp/commands.json"
"$REAL_PYTHON" -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    commands = json.load(f)
names = {item["name"] for item in commands}
assert {"apply", "doctor", "restart", "refresh", "shell", "panel", "debug"} <= names
' "$tmp/commands.json"
"$ROOT/dots" theme >"$tmp/theme.out"
grep -q '^dark$' "$tmp/theme.out"

: >"$DOTS_TEST_LOG"
"$ROOT/dots" restart quickshell >/dev/null
grep -q '^systemctl --user restart quickshell.service$' "$DOTS_TEST_LOG"

refresh_home="$tmp/refresh"
mkdir -p "$refresh_home/.cache/dots-shell/quickshell"
touch "$refresh_home/.cache/dots-shell/quickshell/shell.qml"
: >"$DOTS_TEST_LOG"
HOME="$refresh_home" XDG_CACHE_HOME="$refresh_home/.cache" "$ROOT/dots" refresh quickshell >/dev/null
[ ! -e "$refresh_home/.cache/dots-shell/quickshell" ]
grep -q '^systemctl --user restart quickshell.service$' "$DOTS_TEST_LOG"

: >"$DOTS_TEST_LOG"
HOME="$refresh_home" XDG_CACHE_HOME="$refresh_home/.cache" "$ROOT/dots" shell apps >/dev/null
grep -q 'quickshell .*call launcher toggle$' "$DOTS_TEST_LOG"

: >"$DOTS_TEST_LOG"
HOME="$refresh_home" XDG_CACHE_HOME="$refresh_home/.cache" "$ROOT/dots" panel agents >/dev/null
grep -q 'quickshell .*call dots panel agents$' "$DOTS_TEST_LOG"

fresh_home="$tmp/fresh"
mkdir -p "$fresh_home"
if HOME="$fresh_home" XDG_CONFIG_HOME="$fresh_home/.config" XDG_CACHE_HOME="$fresh_home/.cache" "$ROOT/dots" doctor >"$tmp/fresh.out" 2>&1; then
  echo "fresh-state doctor unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'is missing' "$tmp/fresh.out"

conflict_home="$tmp/conflict"
mkdir -p "$conflict_home/.config/hypr"
echo keep >"$conflict_home/.config/hypr/local.conf"
if HOME="$conflict_home" XDG_CONFIG_HOME="$conflict_home/.config" "$ROOT/dots" apply --links-only >"$tmp/conflict.out" 2>&1; then
  echo "apply unexpectedly replaced an unmanaged config directory" >&2
  exit 1
fi
[ -f "$conflict_home/.config/hypr/local.conf" ]
grep -q 'REFUSE.*hypr' "$tmp/conflict.out"

configured_home="$tmp/configured"
mkdir -p "$configured_home"
HOME="$configured_home" XDG_CONFIG_HOME="$configured_home/.config" XDG_CACHE_HOME="$configured_home/.cache" "$ROOT/dots" apply --links-only >"$tmp/apply-links.out"
HOME="$configured_home" XDG_CONFIG_HOME="$configured_home/.config" XDG_CACHE_HOME="$configured_home/.cache" "$configured_home/.local/bin/dots" doctor >"$tmp/configured.out"
grep -q 'Doctor: 0 error(s)' "$tmp/configured.out"

mkdir -p "$configured_home/.cache/waybar" "$configured_home/.cache/dots-shell/quickshell"
touch "$configured_home/.cache/dots-shell/quickshell/shell.qml"
ln -s "$ROOT/waybar" "$configured_home/.config/waybar"
: >"$DOTS_TEST_LOG"
HOME="$configured_home" XDG_CONFIG_HOME="$configured_home/.config" XDG_CACHE_HOME="$configured_home/.cache" "$configured_home/.local/bin/dots" apply >"$tmp/apply.out"
[ ! -e "$configured_home/.config/waybar" ]
[ ! -e "$configured_home/.cache/waybar" ]
[ ! -e "$configured_home/.cache/dots-shell/quickshell" ]
grep -q '^systemctl --user try-restart quickshell.service$' "$DOTS_TEST_LOG"
grep -q 'Doctor: 0 error(s)' "$tmp/apply.out"

HOME="$configured_home" XDG_CONFIG_HOME="$configured_home/.config" XDG_CACHE_HOME="$configured_home/.cache" "$configured_home/.local/bin/dots" debug --no-logs >"$tmp/debug.out"
grep -q '^== repository ==$' "$tmp/debug.out"
grep -q '^== doctor summary ==$' "$tmp/debug.out"

legacy_home="$tmp/legacy"
mkdir -p "$legacy_home"
HOME="$legacy_home" XDG_CONFIG_HOME="$legacy_home/.config" "$ROOT/bootstrap.sh" --link >"$tmp/bootstrap.out"
[ -L "$legacy_home/.local/bin/dots" ]
[ -L "$legacy_home/.config/quickshell" ]

echo "dots tests: ok"
