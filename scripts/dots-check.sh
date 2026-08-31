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
    compile(path.read_bytes(), str(path), 'exec')
PY
}

check_generated() {
  echo "== generated / reproducibility =="
  python3 scripts/generate-theme.py --check
  python3 - <<'PY'
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

sys.path.insert(0, str(root / "telegram"))
telegram = load("dots_telegram_theme", root / "telegram/generate-theme.py")
colors = telegram.load_colors()
palette_a = telegram.apply_telegram_overrides(telegram.render(colors))
palette_b = telegram.apply_telegram_overrides(telegram.render(colors))
primary_a = telegram.read_primary_background()
primary_b = telegram.read_primary_background()
backup_a = telegram.render_backup_background(colors)
backup_b = telegram.render_backup_background(colors)
archive_a = telegram.build_archive(palette_a, primary_a)
archive_b = telegram.build_archive(palette_b, primary_b)
if (palette_a, primary_a, backup_a, archive_a) != (palette_b, primary_b, backup_b, archive_b):
    raise SystemExit("telegram/generate-theme.py is not reproducible")
tracked_palette = root / "telegram/colors.tdesktop-theme"
if not tracked_palette.exists() or tracked_palette.read_text() != palette_a:
    raise SystemExit("stale generated Telegram palette: telegram/colors.tdesktop-theme")
PY
  python3 scripts/dots-state.py verify-generators --profile desktop
}

check_tests() {
  echo "== tests =="
  bash tests/dots.sh
  bash tests/dots-state.sh
  bash tests/dots-machine.sh
}

case "${1:-all}" in
  all)
    check_shell
    check_lua
    check_python
    check_generated
    check_tests
    ;;
  shell|sh) check_shell ;;
  lua) check_lua ;;
  python|py) check_python ;;
  generated|gen|g) check_generated ;;
  tests|t) check_tests ;;
  help|-h|--help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
