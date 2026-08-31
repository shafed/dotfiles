#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
fake_bin="$tmp/bin"
mkdir -p "$home" "$fake_bin"

python3 - "$ROOT/profiles/base.toml" "$fake_bin" <<'PY'
from pathlib import Path
import sys, tomllib
profile = tomllib.loads(Path(sys.argv[1]).read_text())
bin_dir = Path(sys.argv[2])
for item in profile.get("packages", []):
    command = item["command"]
    if command == "python3":
        continue
    path = bin_dir / command
    path.write_text("#!/usr/bin/env bash\nexit 0\n")
    path.chmod(0o755)
PY
export PATH="$fake_bin:$PATH"

env_base=(HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state")

env "${env_base[@]}" "$ROOT/dots" plan --profile base --json >"$tmp/plan-before.json"
python3 - "$tmp/plan-before.json" <<'PY'
import json, sys
plan = json.load(open(sys.argv[1], encoding="utf-8"))
assert plan["profiles"] == ["base"]
assert plan["summary"]["drift_changes"] > 0
assert not plan["blockers"]
PY
[ ! -e "$home/.local/state/dotfiles/runs" ]

env "${env_base[@]}" "$ROOT/dots" apply --links-only --profile base >/dev/null
env "${env_base[@]}" "$ROOT/dots" plan --links-only --profile base --json >"$tmp/plan-after.json"
python3 - "$tmp/plan-after.json" <<'PY'
import json, sys
plan = json.load(open(sys.argv[1], encoding="utf-8"))
assert plan["summary"]["drift_changes"] == 0, plan["changes"]
assert plan["summary"]["no_op"] is True
PY

mapfile -t runs < <(find "$home/.local/state/dotfiles/runs" -type f -name '*.json' -print)
[ "${#runs[@]}" -eq 1 ]
first_run="$(basename "${runs[0]}" .json)"
env "${env_base[@]}" "$ROOT/dots" show "$first_run" --json >"$tmp/show.json"
grep -q '"status": "applied"' "$tmp/show.json"

env "${env_base[@]}" "$ROOT/dots" apply --links-only --profile base >/dev/null
mapfile -t runs_after_noop < <(find "$home/.local/state/dotfiles/runs" -type f -name '*.json' -print)
[ "${#runs_after_noop[@]}" -eq 1 ]

env "${env_base[@]}" "$ROOT/dots" doctor --profile base --json >"$tmp/doctor.json"
python3 - "$tmp/doctor.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["summary"]["errors"] == 0, report["errors"]
PY

env "${env_base[@]}" "$ROOT/dots" rollback "$first_run" >/dev/null
[ ! -e "$home/.config/kitty" ]
[ ! -e "$home/.local/bin/sudo" ]

env "${env_base[@]}" "$ROOT/dots" apply --links-only --profile base >/dev/null
mapfile -t apply_runs < <(python3 - "$home/.local/state/dotfiles/runs" <<'PY'
from pathlib import Path
import json, sys
for path in sorted(Path(sys.argv[1]).glob('*.json')):
    data=json.loads(path.read_text())
    if data.get('operation','apply') == 'apply' and not data.get('rolled_back_by'):
        print(path)
PY
)
second_run="$(basename "${apply_runs[-1]}" .json)"
printf 'manual change\n' >"$home/.local/bin/sudo"
if env "${env_base[@]}" "$ROOT/dots" rollback "$second_run" >"$tmp/refuse.out" 2>&1; then
  echo "rollback unexpectedly overwrote a later manual change" >&2
  exit 1
fi
grep -q 'changed since run' "$tmp/refuse.out"
grep -q '^manual change$' "$home/.local/bin/sudo"

profile_home="$tmp/profile-home"
profile_env=(HOME="$profile_home" XDG_CONFIG_HOME="$profile_home/.config" XDG_DATA_HOME="$profile_home/.local/share" XDG_CACHE_HOME="$profile_home/.cache" XDG_STATE_HOME="$profile_home/.local/state")
mkdir -p "$profile_home"
env "${profile_env[@]}" "$ROOT/dots" apply --links-only --profile desktop >/dev/null
env "${profile_env[@]}" "$ROOT/dots" plan --links-only --profile base --json >"$tmp/profile-drift.json"
python3 - "$tmp/profile-drift.json" <<'PY'
import json, sys
plan=json.load(open(sys.argv[1], encoding='utf-8'))
removed={item.get('path','') for item in plan['changes'] if item['action']=='remove'}
assert any(path.endswith('/.config/hypr') for path in removed), removed
assert any(path.endswith('/.config/quickshell') for path in removed), removed
PY

echo "dots state tests: ok"
