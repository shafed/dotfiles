#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/helium/apply-gruvbox-theme.py"

real_home="${DOTS_REAL_HOME:-$HOME}"
if [ "$HOME" = "$real_home" ]; then
  exit 0
fi

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
real_data_home="${DOTS_REAL_XDG_DATA_HOME:-$real_home/.local/share}"
flags="$config_home/helium-browser-flags.conf"
[ -f "$flags" ] || exit 0

python3 - "$flags" "$HOME" "$data_home/dotfiles/helium-gruvbox" "$real_home" "$real_data_home/dotfiles/helium-gruvbox" <<'PY'
from pathlib import Path
import sys

flags, temp_home, temp_install, real_home, real_install = map(Path, sys.argv[1:])


def wrapper_safe(path: Path, home: Path) -> str:
    path_s = str(path)
    home_s = str(home)
    if path_s == home_s or path_s.startswith(home_s + "/"):
        parent = str(home.parent).rstrip("/") or "/"
        return f"{parent}/./{home.name}{path_s[len(home_s):]}"
    return path_s

text = flags.read_text()
text = text.replace(wrapper_safe(temp_install, temp_home), wrapper_safe(real_install, real_home))
flags.write_text(text)
PY
