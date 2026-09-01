#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dots-telegram-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_DATA_HOME="$tmp/data"
export TMPDIR="$tmp/tmp"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$TMPDIR"

target="$XDG_DATA_HOME/dotfiles/telegram/current.tdesktop-theme"

bash "$ROOT/scripts/dots-telegram-generator.sh" light >/dev/null
[[ -f "$target" ]]
light_inode="$(stat -c %i "$target")"
light_sum="$(sha256sum "$target" | awk '{print $1}')"
python3 - "$target" "$ROOT/telegram/background.png" <<'PY'
from pathlib import Path
import sys
import zipfile

path = Path(sys.argv[1])
background_source = Path(sys.argv[2]).read_bytes()
with zipfile.ZipFile(path) as archive:
    palette = archive.read("colors.tdesktop-theme").decode()
    background = archive.read("background.png")
if background != background_source:
    raise SystemExit("runtime theme did not embed telegram/background.png verbatim")
if "GB_BG: #41423b;" not in palette:
    raise SystemExit("day palette was not written to runtime theme")
if "historyTextInFg: GB_FG_BRIGHT;" not in palette:
    raise SystemExit("day palette lost its high-contrast message text")
if "historyComposeAreaFg: GB_FG_UI;" not in palette:
    raise SystemExit("day compose text is not using the bright UI foreground")
if "msgInBg: #41423b;" not in palette:
    raise SystemExit("day palette lost its daylight incoming bubble")
PY

bash "$ROOT/scripts/dots-telegram-generator.sh" dark >/dev/null
dark_inode="$(stat -c %i "$target")"
dark_sum="$(sha256sum "$target" | awk '{print $1}')"
[[ "$dark_inode" == "$light_inode" ]]
[[ "$dark_sum" != "$light_sum" ]]
python3 - "$target" <<'PY'
from pathlib import Path
import sys
import zipfile

path = Path(sys.argv[1])
with zipfile.ZipFile(path) as archive:
    palette = archive.read("colors.tdesktop-theme").decode()
if "GB_BG: #282828;" not in palette:
    raise SystemExit("night palette was not written to runtime theme")
if "GB_FG: #d4be98;" not in palette:
    raise SystemExit("night palette lost the warm Gruvbox foreground")
if "historyTextInFg: GB_FG;" not in palette or "historyTextOutFg: GB_FG;" not in palette:
    raise SystemExit("night message text is not using the original Gruvbox foreground")
if "historyComposeAreaFg: GB_FG;" not in palette:
    raise SystemExit("night compose text is not using the original Gruvbox foreground")
if "msgInBg: GB_BG_ALT;" not in palette:
    raise SystemExit("night incoming bubble is not using the original Gruvbox surface")
if "msgInDateFg: GB_GRAY_DIM;" not in palette or "msgOutDateFg: GB_GRAY_DIM;" not in palette:
    raise SystemExit("night message metadata is brighter than the original Gruvbox theme")
PY

bash "$ROOT/scripts/dots-telegram-generator.sh" light >/dev/null
final_inode="$(stat -c %i "$target")"
final_sum="$(sha256sum "$target" | awk '{print $1}')"
[[ "$final_inode" == "$light_inode" ]]
[[ "$final_sum" == "$light_sum" ]]

printf 'telegram theme switch: ok\n'
