#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
state="${1:-auto}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
state_target="$data_home/dotfiles/telegram/current.tdesktop-theme"
repo_target="${DOTS_TELEGRAM_CURRENT:-$ROOT/telegram/current.tdesktop-theme}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dots-telegram-theme.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

tmp_data="$tmp/data"
XDG_DATA_HOME="$tmp_data" python3 "$ROOT/telegram/generate-theme.py" \
  --runtime "$state" >/dev/null
source="$tmp_data/dotfiles/telegram/current.tdesktop-theme"

rewrite_stable() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if [[ -e "$target" ]]; then
    if cmp -s "$source" "$target"; then
      return 0
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
}

# Keep the profile-managed mirror for deterministic dots plan/apply checks.
rewrite_stable "$source" "$state_target"

# This is the path the user imports manually in Telegram. generator_render sets
# DOTS_REAL_HOME while evaluating a profile in an isolated HOME; do not mutate
# the checkout during that dry run.
if [[ -z "${DOTS_REAL_HOME:-}" ]]; then
  rewrite_stable "$source" "$repo_target"
  printf '%s\n' "$repo_target ($state)"
else
  printf '%s\n' "$state_target ($state)"
fi
