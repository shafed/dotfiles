#!/usr/bin/env python3
"""Build the Telegram Desktop Gruvbox theme, including its wallpaper."""

from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path
import sys
import zipfile

from _palette_renderer import load_colors, render

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
PALETTE_OUTPUT = HERE / "colors.tdesktop-theme"
BACKGROUND = HERE / "background.jpg"
OUTPUT = HERE / "gruvbox-material-dark-medium.tdesktop-theme"


def zip_entry(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    return info


def apply_telegram_overrides(palette: str) -> str:
    """Add Telegram-only colors that are not part of the shared surfaces."""
    sidebar = """

// Telegram folder sidebar.
sideBarBg: GB_BG;
sideBarBgActive: GB_BG_SOFT;
sideBarBgRipple: GB_BG_HOVER;
sideBarTextFg: GB_GRAY_DIM;
sideBarTextFgActive: GB_YELLOW;
sideBarIconFg: GB_GRAY_DIM;
sideBarIconFgActive: GB_YELLOW;
sideBarBadgeBg: GB_YELLOW;
sideBarBadgeBgMuted: GB_BG_MUTED;
sideBarBadgeFg: GB_BG_HARD;
"""
    marker = '\n// Generic scrollbars.\n'
    if marker not in palette:
        raise ValueError("Telegram palette insertion anchor not found")
    return palette.replace(marker, sidebar + marker, 1)


def build_archive(palette: str) -> bytes:
    if not BACKGROUND.is_file():
        raise FileNotFoundError(f"Telegram background not found: {BACKGROUND}")
    buffer = BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        archive.writestr(zip_entry("colors.tdesktop-theme"), palette.encode())
        archive.writestr(zip_entry("background.jpg"), BACKGROUND.read_bytes())
    return buffer.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if tracked Telegram palette is stale")
    parser.add_argument("--stdout", action="store_true", help="print the generated palette instead of writing files")
    args = parser.parse_args()

    palette = apply_telegram_overrides(render(load_colors()))
    if args.stdout:
        print(palette, end="")
        return 0

    if args.check:
        if not PALETTE_OUTPUT.exists() or PALETTE_OUTPUT.read_text() != palette:
            print(f"stale generated Telegram palette: {PALETTE_OUTPUT.relative_to(ROOT)}", file=sys.stderr)
            return 1
        if OUTPUT.exists() and OUTPUT.read_bytes() != build_archive(palette):
            print(f"stale generated Telegram archive: {OUTPUT.relative_to(ROOT)}", file=sys.stderr)
            return 1
        return 0

    PALETTE_OUTPUT.write_text(palette)
    OUTPUT.write_bytes(build_archive(palette))
    print(OUTPUT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
