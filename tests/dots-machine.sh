#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fake_bin="$tmp/bin"
home="$tmp/home"
mkdir -p "$fake_bin" "$home"

# Make all required base commands appear installed except bruvtab. Keeping only
# the uv-tool missing lets provision dry-run be tested on non-Arch CI without
# pretending that pacman is available as an installer.
python3 - "$ROOT/profiles/base.toml" "$fake_bin" <<'PY'
from pathlib import Path
import sys, tomllib
profile = tomllib.loads(Path(sys.argv[1]).read_text())
bin_dir = Path(sys.argv[2])
for item in profile.get("packages", []):
    if not item.get("required", True):
        continue
    command = item["command"]
    if command in {"python3", "bruvtab", "uv"}:
        continue
    path = bin_dir / command
    path.write_text("#!/usr/bin/env bash\nexit 0\n")
    path.chmod(0o755)
PY

cat >"$fake_bin/uv" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${DOTS_UV_MARKER:?}"
EOF
chmod +x "$fake_bin/uv"

cat >"$fake_bin/pacman" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-Qqe" ]; then
  echo old-test-package
  exit 0
fi
exit 0
EOF
chmod +x "$fake_bin/pacman"

cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "--user show-environment") exit 0 ;;
  "--user is-enabled forgotten-test.service") echo enabled; exit 0 ;;
  "--user is-enabled "*) echo disabled; exit 1 ;;
  "--user is-active "*) echo inactive; exit 3 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$fake_bin/systemctl"

export PATH="$fake_bin:$PATH"
export DOTS_UV_MARKER="$tmp/uv-called"
env_base=(HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state")

# Dry-run emits an exact action and never invokes the installer.
env "${env_base[@]}" "$ROOT/dots" provision --dry-run --profile base --json >"$tmp/provision.json"
[ ! -e "$DOTS_UV_MARKER" ]
python3 - "$tmp/provision.json" <<'PY'
import json, sys
result=json.load(open(sys.argv[1], encoding='utf-8'))
assert result['type'] == 'provision'
assert result['dry_run'] is True
assert result['summary']['blockers'] == 0, result['blockers']
assert [item['package'] for item in result['missing']] == ['bruvtab']
assert len(result['actions']) == 1
argv=result['actions'][0]['argv']
assert argv[-3:] == ['tool', 'install', 'bruvtab'], argv
PY

# Converge only base-managed files, then show that package/service extras are
# informational drift rather than a reason for a destructive cleanup.
env "${env_base[@]}" "$ROOT/dots" apply --links-only --profile base >/dev/null
mkdir -p "$home/.config/systemd/user"
printf '[Unit]\nDescription=test\n' >"$home/.config/systemd/user/forgotten-test.service"
# The missing bruvtab command would be required drift; expose it after apply so
# drift can test the fully-converged required path while keeping dry-run above.
cat >"$fake_bin/bruvtab" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fake_bin/bruvtab"

env "${env_base[@]}" "$ROOT/dots" drift --profile base --json >"$tmp/drift.json"
python3 - "$tmp/drift.json" <<'PY'
import json, sys
result=json.load(open(sys.argv[1], encoding='utf-8'))
assert result['summary']['required_drift'] is False, result
assert result['extra_explicit_packages'] == ['old-test-package'], result['extra_explicit_packages']
assert result['unexpected_user_services'] == ['forgotten-test.service']
PY

# A real unmanaged file is a blocker, and plan must leave it untouched.
block_home="$tmp/block-home"
mkdir -p "$block_home"
printf 'keep me\n' >"$block_home/.zshrc"
if HOME="$block_home" XDG_CONFIG_HOME="$block_home/.config" XDG_DATA_HOME="$block_home/.local/share" XDG_CACHE_HOME="$block_home/.cache" XDG_STATE_HOME="$block_home/.local/state" \
  "$ROOT/dots" plan --profile base --json >"$tmp/block-plan.json" 2>/dev/null; then
  echo "plan unexpectedly accepted an unmanaged real file" >&2
  exit 1
fi
grep -q '^keep me$' "$block_home/.zshrc"
[ "$(find "$block_home" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')" = ".zshrc " ]
python3 - "$tmp/block-plan.json" <<'PY'
import json, sys
plan=json.load(open(sys.argv[1], encoding='utf-8'))
assert any('.zshrc exists and is not a symlink' in item for item in plan['blockers']), plan['blockers']
PY

echo "dots machine tests: ok"
