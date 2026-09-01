#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "Usage: dots check [all|shell|lua|python|generated|tests]"
}

check_shell() {
  echo "== shell =="
  while IFS= read -r -d '' file; do
    bash -n "$file" || return
  done < <(find . -type f \( -name '*.sh' -o -name dots \) -not -path './.git/*' -print0)
}

check_lua() {
  echo "== lua =="
  if ! command -v luac >/dev/null 2>&1; then
    echo "luac is required for Lua checks (Arch package: lua)" >&2
    return 1
  fi
  while IFS= read -r -d '' file; do
    luac -p "$file" || return
  done < <(find . -type f -name '*.lua' -not -path './.git/*' -print0)
}

check_python() {
  echo "== python =="
  if ! python3 - <<'PY'
from pathlib import Path

for path in Path('.').rglob('*.py'):
    if '.git' in path.parts:
        continue
    compile(path.read_bytes(), str(path), 'exec')
PY
  then
    return 1
  fi
}

check_generated() {
  echo "== generated / reproducibility =="
  python3 scripts/generate-theme.py --check || return
  python3 scripts/generate-theme.py --mode light --check || return
  if ! python3 - <<'PY'
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys

root = Path.cwd()

def load(name, path):
    spec = spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

theme = load("dots_generate_theme", root / "scripts/generate-theme.py")
first = theme.generated_files(theme.load_colors())
second = theme.generated_files(theme.load_colors())
if first != second:
    raise SystemExit("scripts/generate-theme.py is not reproducible")

light = theme.load_colors("light")
if light["bg"] != "#fbfaf7" or light["fg"] != "#3c3836":
    raise SystemExit("Helium daylight palette anchors drifted")

sys.path.insert(0, str(root / "telegram"))
telegram = load("dots_telegram_theme", root / "telegram/generate-theme.py")
colors = telegram.load_colors()
background_a = telegram.read_background()
background_b = telegram.read_background()

pairs = []
for variant in ("day", "night"):
    palette_a = telegram.render_variant(colors, variant)
    palette_b = telegram.render_variant(colors, variant)
    archive_a = telegram.build_archive(palette_a, background_a)
    archive_b = telegram.build_archive(palette_b, background_b)
    pairs.append((palette_a, palette_b, archive_a, archive_b))

if background_a != background_b:
    raise SystemExit("telegram/generate-theme.py background input is not reproducible")
if any(palette_a != palette_b or archive_a != archive_b for palette_a, palette_b, archive_a, archive_b in pairs):
    raise SystemExit("telegram/generate-theme.py variants are not reproducible")
if pairs[0][0] == pairs[1][0]:
    raise SystemExit("Telegram day and night palettes unexpectedly match")
PY
  then
    return 1
  fi
  python3 tests/helium-theme.py || return
  python3 scripts/dots-state.py verify-generators --profile desktop || return
}

check_tests() {
  echo "== tests =="
  bash tests/dots.sh || return
  bash tests/dots-state.sh || return
  bash tests/dots-machine.sh || return
  bash tests/telegram-theme.sh || return
  bash tests/copyq-theme.sh || return
}

run_check() {
  local output rc
  output="$(mktemp)"
  if "$1" >"$output" 2>&1; then
    cat "$output"
    rm -f "$output"
    return 0
  else
    rc=$?
  fi

  cat "$output"
  rm -f "$output"
  return "$rc"
}

case "${1:-all}" in
  all)
    run_check check_shell
    run_check check_lua
    run_check check_python
    run_check check_generated
    run_check check_tests
    ;;
  shell|sh) run_check check_shell ;;
  lua) run_check check_lua ;;
  python|py) run_check check_python ;;
  generated|gen|g) run_check check_generated ;;
  tests|t) run_check check_tests ;;
  help|-h|--help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
