#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "Usage: dots check [all|shell|lua|python|tests]"
}

check_shell() {
  echo "== shell =="
  while IFS= read -r -d '' file; do
    bash -n "$file"
  done < <(find . -type f \( -name '*.sh' -o -name dots \) -not -path './.git/*' -print0)
}

check_lua() {
  echo "== lua =="
  if ! command -v luac >/dev/null 2>&1; then
    echo "luac is required for Lua checks (Arch package: lua)" >&2
    return 1
  fi
  while IFS= read -r -d '' file; do
    luac -p "$file"
  done < <(find . -type f -name '*.lua' -not -path './.git/*' -print0)
}

check_python() {
  echo "== python =="
  python3 - <<'PY'
from pathlib import Path

for path in Path('.').rglob('*.py'):
    if '.git' in path.parts:
        continue
    source = path.read_bytes()
    compile(source, str(path), 'exec')
PY
}

check_tests() {
  echo "== tests =="
  tests/dots.sh
}

case "${1:-all}" in
  all)
    check_shell
    check_lua
    check_python
    check_tests
    ;;
  shell|sh) check_shell ;;
  lua) check_lua ;;
  python|py) check_python ;;
  tests|t) check_tests ;;
  help|-h|--help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
