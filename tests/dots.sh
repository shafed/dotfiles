#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/dots-lib.sh
source "$ROOT/scripts/dots-lib.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fake_bin="$tmp/bin"
mkdir -p "$fake_bin"

for entry in "${REQUIRED_PKGS[@]}"; do
  cmd="${entry%%:*}"
  if [ "$cmd" = "darkman" ]; then
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
esac
SH
chmod +x "$fake_bin/darkman"

cat > "$fake_bin/systemctl" <<'SH'
#!/usr/bin/env bash
args="$*"
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

"$ROOT/dots" help | grep -q '^  doctor'
"$ROOT/dots" theme | grep -q '^dark$'

fresh_home="$tmp/fresh"
mkdir -p "$fresh_home"
if HOME="$fresh_home" XDG_CONFIG_HOME="$fresh_home/.config" XDG_CACHE_HOME="$fresh_home/.cache" "$ROOT/dots" doctor >"$tmp/fresh.out" 2>&1; then
  echo "fresh-state doctor unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'is missing' "$tmp/fresh.out"

configured_home="$tmp/configured"
mkdir -p "$configured_home"
HOME="$configured_home" XDG_CONFIG_HOME="$configured_home/.config" XDG_CACHE_HOME="$configured_home/.cache" "$ROOT/bootstrap.sh" --link >"$tmp/bootstrap.out"
HOME="$configured_home" XDG_CONFIG_HOME="$configured_home/.config" XDG_CACHE_HOME="$configured_home/.cache" "$configured_home/.local/bin/dots" doctor >"$tmp/configured.out"
grep -q 'Doctor: 0 error(s)' "$tmp/configured.out"

mkdir -p "$configured_home/.cache/waybar"
ln -s "$ROOT/waybar" "$configured_home/.config/waybar"
if HOME="$configured_home" XDG_CONFIG_HOME="$configured_home/.config" XDG_CACHE_HOME="$configured_home/.cache" "$configured_home/.local/bin/dots" migrate --check >/dev/null 2>&1; then
  echo "migration check unexpectedly reported clean" >&2
  exit 1
fi
HOME="$configured_home" XDG_CONFIG_HOME="$configured_home/.config" XDG_CACHE_HOME="$configured_home/.cache" "$configured_home/.local/bin/dots" migrate >/dev/null
[ ! -e "$configured_home/.config/waybar" ]
[ ! -e "$configured_home/.cache/waybar" ]

echo "dots tests: ok"
