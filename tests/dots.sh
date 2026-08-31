#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_PYTHON="$(command -v python3)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fake_bin="$tmp/bin"
mkdir -p "$fake_bin"
export DOTS_TEST_LOG="$tmp/calls.log"
: >"$DOTS_TEST_LOG"

cat >"$fake_bin/darkman" <<'EOF'
#!/usr/bin/env bash
case "${1:-get}" in
get) echo dark ;;
*) exit 0 ;;
esac
EOF
cat >"$fake_bin/quickshell" <<'EOF'
#!/usr/bin/env bash
printf 'quickshell %s\n' "$*" >>"${DOTS_TEST_LOG:-/dev/null}"
EOF
cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"${DOTS_TEST_LOG:-/dev/null}"
case "$*" in
  "--user show-environment") exit 0 ;;
  "--user is-enabled dunst.service") echo masked; exit 0 ;;
  "--user is-enabled waybar.service") echo disabled; exit 1 ;;
  "--user is-active waybar.service") echo inactive; exit 3 ;;
  "--user is-enabled quickshell.service"|"--user is-enabled kanata.service"|"--user is-enabled darkman.service"|"--user is-enabled copyq.service") echo enabled; exit 0 ;;
  "--user is-active graphical-session.target"|"--user is-active quickshell.service"|"--user is-active kanata.service.service"|"--user is-active darkman.service") echo active; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$fake_bin/darkman" "$fake_bin/quickshell" "$fake_bin/systemctl"
export PATH="$fake_bin:$PATH"

"$ROOT/dots" help >"$tmp/help.out"
for command in plan apply drift provision doctor history show rollback aliases completion; do
  grep -q "^  $command" "$tmp/help.out"
done
! grep -q '^  stage' "$tmp/help.out"
for command in drift provision rollback aliases completion; do
  "$ROOT/dots" help "$command" >"$tmp/$command-help.out"
  grep -q "^Usage: dots $command" "$tmp/$command-help.out"
done
"$ROOT/dots" help hi >"$tmp/history-alias-help.out"
grep -q '^Usage: dots history' "$tmp/history-alias-help.out"
"$ROOT/dots" sh --help >"$tmp/show-alias-help.out"
grep -q '^Usage: dots show' "$tmp/show-alias-help.out"

"$ROOT/dots" commands --json >"$tmp/commands.json"
"$REAL_PYTHON" - "$tmp/commands.json" <<'PY'
import json, sys
items = json.load(open(sys.argv[1], encoding="utf-8"))
by_name = {item["name"]: item for item in items}
assert {"plan", "apply", "drift", "provision", "doctor", "history", "show", "rollback", "aliases", "completion"} <= set(by_name)
assert "stage" not in by_name
assert by_name["plan"]["aliases"] == ["pl"]
assert by_name["history"]["aliases"] == ["hi", "hist"]
assert by_name["show"]["aliases"] == ["sh"]
assert by_name["aliases"]["aliases"] == ["al"]
PY

"$ROOT/dots" aliases >"$tmp/aliases.out"
grep -Eq '^pl[[:space:]]+plan$' "$tmp/aliases.out"
grep -Eq '^hi[[:space:]]+history$' "$tmp/aliases.out"
grep -Eq '^hist[[:space:]]+history$' "$tmp/aliases.out"
grep -Eq '^sh[[:space:]]+show$' "$tmp/aliases.out"
grep -Eq '^al[[:space:]]+aliases$' "$tmp/aliases.out"
"$ROOT/dots" aliases --json >"$tmp/aliases.json"
"$REAL_PYTHON" - "$tmp/aliases.json" <<'PY'
import json, sys
pairs = {(item["alias"], item["command"]) for item in json.load(open(sys.argv[1], encoding="utf-8"))}
assert ("pl", "plan") in pairs
assert ("hi", "history") in pairs
assert ("sh", "show") in pairs
assert all(command != "stage" for _, command in pairs)
PY

"$ROOT/dots" completion zsh >"$tmp/dots-completion.zsh"
grep -q "'plan:Preview exactly what apply would change'" "$tmp/dots-completion.zsh"
! grep -q "'pl:" "$tmp/dots-completion.zsh"
! grep -q 'alias for' "$tmp/dots-completion.zsh"
! grep -q 'compdef _dots dots ds' "$tmp/dots-completion.zsh"
! grep -q 'stage' "$tmp/dots-completion.zsh"
if ! command -v zsh >/dev/null 2>&1; then
  echo "zsh is required for dots completion tests" >&2
  exit 1
fi

zsh - "$tmp/dots-completion.zsh" <<'ZSH'
set -e
source "$1"
(( $+functions[_dots] ))
ZSH

grep -q -- '--json\[machine-readable output\]' "$tmp/dots-completion.zsh"
grep -q -- '--machine\[select a machine manifest\]' "$tmp/dots-completion.zsh"
grep -q -- '--profile\[override selected profiles\]' "$tmp/dots-completion.zsh"
grep -q '1:check scope:(all shell lua python generated tests)' "$tmp/dots-completion.zsh"
grep -q '1:theme action:(status light dark toggle)' "$tmp/dots-completion.zsh"
grep -q '1:panel:(system audio network bluetooth power agents updates notifications calendar)' "$tmp/dots-completion.zsh"
! grep -q "'(-h --help)'" "$tmp/dots-completion.zsh"

grep -q 'eval "$("\$DOTFILES/dots" completion zsh)"' "$ROOT/zsh/zshrc"
grep -q 'compdef _dots dots ds' "$ROOT/zsh/zshrc"
[ ! -e "$ROOT/zsh/completions/_dots" ]
[ ! -e "$ROOT/scripts/dots-stage.sh" ]
if "$ROOT/dots" stage >"$tmp/stage.out" 2>&1; then
  echo "removed stage command unexpectedly succeeded" >&2
  exit 1
fi
grep -q 'unknown command: stage' "$tmp/stage.out"

"$ROOT/dots" theme >"$tmp/theme.out"
grep -q '^dark$' "$tmp/theme.out"
: >"$DOTS_TEST_LOG"
"$ROOT/dots" rs q >/dev/null
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

conflict_home="$tmp/conflict"
mkdir -p "$conflict_home/.config/kitty"
printf 'keep\n' >"$conflict_home/.config/kitty/local.conf"
if HOME="$conflict_home" XDG_CONFIG_HOME="$conflict_home/.config" "$ROOT/dots" apply --links-only --profile base >"$tmp/conflict.out" 2>&1; then
  echo "apply unexpectedly replaced an unmanaged config directory" >&2
  exit 1
fi
[ -f "$conflict_home/.config/kitty/local.conf" ]
grep -q 'exists and is not a symlink' "$tmp/conflict.out"

migration_home="$tmp/migration"
mkdir -p "$migration_home/.config"
ln -s "$ROOT/waybar" "$migration_home/.config/waybar"
HOME="$migration_home" XDG_CONFIG_HOME="$migration_home/.config" XDG_CACHE_HOME="$migration_home/.cache" XDG_STATE_HOME="$migration_home/.local/state" \
  "$ROOT/dots" migrate >/dev/null
[ ! -L "$migration_home/.config/waybar" ]
mapfile -t backups < <(find "$migration_home/.local/state/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d -print)
[ "${#backups[@]}" -eq 1 ]
[ -L "${backups[0]}/.config/waybar" ]

echo "dots tests: ok"
