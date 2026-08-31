#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
help|-h|--help)
  cat <<'USAGE'
Usage: dots apply [--check|--links-only] [--machine name] [--profile names]

Bring this machine in line with the selected profile.
  --check       Show the plan only; do not change the machine
  --links-only  Apply only managed links/files; skip generators, migrations, services and doctor
  --machine     Select machines/<name>.toml instead of hostname/default
  --profile     Comma-separated profile override for testing
USAGE
  exit 0
  ;;
esac

export DOTS_REAL_HOME="${DOTS_REAL_HOME:-$HOME}"
export DOTS_REAL_XDG_DATA_HOME="${DOTS_REAL_XDG_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}}"

args=("$@")
plan_args=()
check_only=0
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
  --check)
    check_only=1
    ;;
  --links-only|--link)
    plan_args+=(--links-only)
    ;;
  --machine|--profile)
    plan_args+=("${args[$i]}")
    if ((i + 1 < ${#args[@]})); then
      ((i += 1))
      plan_args+=("${args[$i]}")
    fi
    ;;
  --machine=*|--profile=*)
    plan_args+=("${args[$i]}")
    ;;
  esac
done

if [ "$check_only" -eq 1 ]; then
  exec python3 "$ROOT/scripts/dots-state.py" apply "$@"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
plan_file="$tmp/plan.json"
before_file="$tmp/runs-before"
after_file="$tmp/runs-after"
runs_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/runs"

list_runs() {
  if [ ! -d "$runs_dir" ]; then
    return 0
  fi
  local path
  for path in "$runs_dir"/*.json; do
    [ -e "$path" ] || continue
    basename "$path"
  done | sort
}

list_runs >"$before_file"
plan_rc=0
python3 "$ROOT/scripts/dots-state.py" plan --json "${plan_args[@]}" >"$plan_file" || plan_rc=$?

apply_rc=0
python3 "$ROOT/scripts/dots-state.py" apply "$@" || apply_rc=$?

list_runs >"$after_file"
if [ -s "$plan_file" ]; then
  while IFS= read -r run_name; do
    [ -n "$run_name" ] || continue
    python3 "$ROOT/scripts/dots-run-enrich.py" \
      --run "$runs_dir/$run_name" \
      --plan "$plan_file" || true
  done < <(comm -13 "$before_file" "$after_file")
fi

# A blocker makes the preview non-zero, but the apply result remains the public
# exit code. plan_rc is kept only so the preview step never short-circuits apply.
: "$plan_rc"
exit "$apply_rc"
