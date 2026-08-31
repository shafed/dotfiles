#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state="${1:-auto}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
target="$data_home/dotfiles/telegram/current.tdesktop-theme"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dots-telegram-theme.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

tmp_data="$tmp/data"
XDG_DATA_HOME="$tmp_data" python3 "$ROOT/telegram/generate-theme.py" \
  --runtime "$state" >/dev/null
source="$tmp_data/dotfiles/telegram/current.tdesktop-theme"

mkdir -p "$(dirname "$target")"

if [[ -e "$target" ]]; then
  if cmp -s "$source" "$target"; then
    printf '%s\n' "$target (unchanged)"
    exit 0
  fi

  # Telegram watches the active local theme with QFileSystemWatcher. Replacing
  # the path with rename(2)/os.replace() swaps the inode and drops that watch.
  # Rewrite the existing inode instead so every later darkman transition is
  # still observed by the running Telegram process.
  python3 - "$source" "$target" <<'PY'
from pathlib import Path
import os
import sys

source = Path(sys.argv[1]).read_bytes()
target = Path(sys.argv[2])
with target.open("r+b") as handle:
    handle.seek(0)
    handle.write(source)
    handle.truncate()
    handle.flush()
    os.fsync(handle.fileno())
PY
else
  install -m 0644 "$source" "$target"
fi

printf '%s\n' "$target ($state)"
