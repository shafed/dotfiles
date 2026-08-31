#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
mkdir -p "$home"

HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state" \
  "$ROOT/dots" plan --profile base --json >"$tmp/plan-before.json"
python3 - "$tmp/plan-before.json" <<'PY'
import json, sys
plan = json.load(open(sys.argv[1], encoding="utf-8"))
assert plan["profiles"] == ["base"]
assert plan["summary"]["changes"] > 0
assert not plan["blockers"]
PY
[ ! -e "$home/.local/state/dotfiles/runs" ]

HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state" \
  "$ROOT/dots" apply --links-only --profile base >/dev/null

HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state" \
  "$ROOT/dots" plan --profile base --json >"$tmp/plan-after.json"
python3 - "$tmp/plan-after.json" <<'PY'
import json, sys
plan = json.load(open(sys.argv[1], encoding="utf-8"))
assert plan["summary"]["changes"] == 0, plan["changes"]
assert plan["summary"]["no_op"] is True
PY

mapfile -t runs < <(find "$home/.local/state/dotfiles/runs" -type f -name '*.json' -print)
[ "${#runs[@]}" -eq 1 ]
run_id="$(basename "${runs[0]}" .json)"
HOME="$home" XDG_STATE_HOME="$home/.local/state" "$ROOT/dots" show "$run_id" --json >"$tmp/show.json"
grep -q '"status": "applied"' "$tmp/show.json"

HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state" \
  "$ROOT/dots" apply --links-only --profile base >/dev/null
mapfile -t runs_after < <(find "$home/.local/state/dotfiles/runs" -type f -name '*.json' -print)
[ "${#runs_after[@]}" -eq 1 ]

echo "dots state tests: ok"
