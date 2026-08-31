#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
service_profile="$ROOT/profiles/test-service-ci.toml"
trap 'rm -f "$service_profile"; rm -rf "$tmp"' EXIT
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

# An isolated HOME must never inspect the real logged-in user's systemd state.
# Keep the user manager unavailable until the explicit service-convergence test
# below replaces this stub with a stateful fake systemctl.
cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "--user show-environment") exit 1 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$fake_bin/systemctl"

export PATH="$fake_bin:$PATH"

python3 - "$ROOT" <<'PY'
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys

root = Path(sys.argv[1])
spec = spec_from_file_location("dots_state", root / "scripts/dots-state.py")
module = module_from_spec(spec)
spec.loader.exec_module(module)
context = module.ctx("default")
assert context["requested_profiles"] == ["desktop"]

desktop_order, desktop = module.desired_for(context, ["desktop"])
assert desktop_order == ["base", "desktop"]
assert "desktop" in desktop["capabilities"]
assert "bluetooth" in desktop["capabilities"]
assert "battery" not in desktop["capabilities"]
assert "powerprofilesctl" not in {item["command"] for item in desktop["packages"]}

laptop_order, laptop = module.desired_for(context, ["laptop"])
assert laptop_order == ["base", "desktop", "laptop"]
assert {"desktop", "bluetooth", "laptop", "battery"} <= set(laptop["capabilities"])
assert {"powerprofilesctl", "brightnessctl"} <= {item["command"] for item in laptop["packages"]}
assert not (root / "profiles/gaming.toml").exists()
PY

env_base=(HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state")

[ -z "$(find "$home" -mindepth 1 -print -quit)" ]
env "${env_base[@]}" "$ROOT/dots" plan --profile base --json >"$tmp/plan-before.json"
[ -z "$(find "$home" -mindepth 1 -print -quit)" ]
python3 - "$tmp/plan-before.json" <<'PY'
import json, sys
plan = json.load(open(sys.argv[1], encoding="utf-8"))
assert plan["schema"] == 2
assert plan["profiles"] == ["base"]
assert isinstance(plan["dependencies"], list)
assert isinstance(plan["changes"], list)
assert isinstance(plan["blockers"], list)
assert plan["summary"]["drift_changes"] > 0
assert not plan["blockers"]
assert "no_op" in plan["summary"]
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
python3 - "$tmp/show.json" <<'PY'
import json, sys
record = json.load(open(sys.argv[1], encoding="utf-8"))
assert record["status"] == "applied"
for key in ("commit", "machine", "profiles", "capabilities", "timestamp", "changes", "backups", "plan", "doctor"):
    assert key in record, key
assert record["plan"]["summary"]["drift_changes"] > 0
assert record["doctor"]["result"]["summary"]["errors"] == 0, record["doctor"]
PY

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

backup_home="$tmp/backup-home"
backup_env=(HOME="$backup_home" XDG_CONFIG_HOME="$backup_home/.config" XDG_DATA_HOME="$backup_home/.local/share" XDG_CACHE_HOME="$backup_home/.cache" XDG_STATE_HOME="$backup_home/.local/state")
mkdir -p "$backup_home"
env "${backup_env[@]}" "$ROOT/dots" apply --links-only --profile base >/dev/null
printf 'local managed edit\n' >"$backup_home/.local/bin/sudo"
env "${backup_env[@]}" "$ROOT/dots" apply --links-only --profile base >/dev/null
latest_apply="$(python3 - "$backup_home/.local/state/dotfiles/runs" <<'PY'
from pathlib import Path
import json, sys
items=[]
for path in Path(sys.argv[1]).glob('*.json'):
    data=json.loads(path.read_text())
    if data.get('operation','apply') == 'apply':
        items.append((data['timestamp'], path))
print(max(items)[1])
PY
)"
python3 - "$latest_apply" "$backup_home/.local/bin/sudo" <<'PY'
import json, sys
from pathlib import Path
record=json.loads(Path(sys.argv[1]).read_text())
source=sys.argv[2]
backup=next(item['backup'] for item in record['backups'] if item['source'] == source)
assert Path(backup).read_text() == 'local managed edit\n'
PY

# Full apply must converge selected user services, not merely link the unit files.
cat >"$service_profile" <<'EOF'
[profile]
description = "CI-only service convergence profile"
includes = ["base"]
capabilities = []
config_dirs = ["systemd"]
services = ["darkman.service"]
EOF
service_home="$tmp/service-home"
service_state="$tmp/darkman-enabled"
service_log="$tmp/systemctl.log"
mkdir -p "$service_home"
cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${DOTS_SERVICE_LOG:?}"
case "$*" in
  "--user show-environment") exit 0 ;;
  "--user is-enabled darkman.service")
    if [ -e "${DOTS_SERVICE_STATE:?}" ]; then echo enabled; exit 0; fi
    echo disabled; exit 1 ;;
  "--user is-active darkman.service")
    if [ -e "${DOTS_SERVICE_STATE:?}" ]; then echo active; exit 0; fi
    echo inactive; exit 3 ;;
  "--user is-active graphical-session.target") echo inactive; exit 3 ;;
  "--user enable --now darkman.service") touch "${DOTS_SERVICE_STATE:?}"; exit 0 ;;
  "--user unmask darkman.service"|"--user daemon-reload"|"--user reset-failed darkman.service"|"--user try-restart darkman.service") exit 0 ;;
  "--user is-enabled "*) echo disabled; exit 1 ;;
  "--user is-active "*) echo inactive; exit 3 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$fake_bin/systemctl"
service_env=(HOME="$service_home" XDG_CONFIG_HOME="$service_home/.config" XDG_DATA_HOME="$service_home/.local/share" XDG_CACHE_HOME="$service_home/.cache" XDG_STATE_HOME="$service_home/.local/state" DOTS_SERVICE_STATE="$service_state" DOTS_SERVICE_LOG="$service_log")

env "${service_env[@]}" "$ROOT/dots" plan --profile test-service-ci --json >"$tmp/service-before.json"
python3 - "$tmp/service-before.json" <<'PY'
import json, sys
plan=json.load(open(sys.argv[1], encoding='utf-8'))
assert any(item['kind']=='service' and item['action']=='enable' and item['unit']=='darkman.service' for item in plan['changes']), plan['changes']
PY

env "${service_env[@]}" "$ROOT/dots" apply --profile test-service-ci >/dev/null
[ -e "$service_state" ]
grep -q '^--user enable --now darkman.service$' "$service_log"
env "${service_env[@]}" "$ROOT/dots" plan --profile test-service-ci --json >"$tmp/service-after.json"
python3 - "$tmp/service-after.json" <<'PY'
import json, sys
plan=json.load(open(sys.argv[1], encoding='utf-8'))
assert not any(item['kind']=='service' and item['action']=='enable' for item in plan['changes']), plan['changes']
assert plan['summary']['no_op'] is True, plan['changes']
PY
rm -f "$service_profile"

echo "dots state tests: ok"
