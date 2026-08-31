#!/usr/bin/env python3
"""Build the Telegram Desktop Gruvbox theme, including its wallpaper."""

from __future__ import annotations

import argparse
import base64
from io import BytesIO
from pathlib import Path
import struct
import sys
import zipfile
import zlib

from _palette_renderer import load_colors, render

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
PALETTE_OUTPUT = HERE / "colors.tdesktop-theme"
BACKGROUND_SOURCE = HERE / "background.png.b64"
BACKGROUND_PRIMARY_OUTPUT = HERE / "background-primary.png"
BACKGROUND_BACKUP_OUTPUT = HERE / "background-backup.png"
OUTPUT = HERE / "gruvbox-material-dark-medium.tdesktop-theme"


def zip_entry(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    return info


def apply_telegram_overrides(palette: str) -> str:
    """Add Telegram-only colors that are not part of the shared surfaces."""
    overrides = """
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

// Voice messages. Telegram exposes unread media only as the small dot after
// the duration; it does not expose a separate palette state for the whole
// idle waveform. Keep the waveform neutral and make that unread dot obvious.
// The dot shares msgFileInBg with the incoming play button, so the button uses
// the same yellow accent as a necessary limitation of the theme format.
msgFileInBg: GB_YELLOW;
msgFileInBgOver: GB_ORANGE;
msgFileInBgSelected: GB_YELLOW;
msgFileOutBg: GB_BLUE;
msgFileOutBgOver: GB_AQUA;
msgFileOutBgSelected: GB_BLUE;
msgWaveformInActive: GB_FG_SOFT;
msgWaveformInActiveSelected: GB_FG_BRIGHT;
msgWaveformInInactive: GB_GRAY;
msgWaveformInInactiveSelected: GB_GRAY_DIM;
msgWaveformOutActive: GB_FG_SOFT;
msgWaveformOutActiveSelected: GB_FG_BRIGHT;
msgWaveformOutInactive: GB_GRAY;
msgWaveformOutInactiveSelected: GB_GRAY_DIM;
"""
    marker = "\n// Generic scrollbars.\n"
    if marker not in palette:
        raise ValueError("Telegram palette insertion anchor not found")
    return palette.replace(marker, overrides + marker, 1)


def rgb(value: str) -> tuple[int, int, int]:
    return tuple(int(value[i : i + 2], 16) for i in (1, 3, 5))


def blend(base: tuple[int, int, int], over: tuple[int, int, int], alpha: int) -> tuple[int, int, int]:
    return tuple((a * (255 - alpha) + b * alpha) // 255 for a, b in zip(base, over))


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def render_backup_background(colors: dict[str, str], width: int = 1600, height: int = 1000) -> bytes:
    """Render the alternate low-contrast Gruvbox wallpaper using stdlib only."""
    base = rgb(colors["bg"])
    soft = rgb(colors["bg_soft"])
    hover = rgb(colors["bg_hover"])
    yellow = rgb(colors["yellow"])
    aqua = rgb(colors["aqua"])

    raw = bytearray()
    tile = 128
    for y in range(height):
        raw.append(0)
        for x in range(width):
            nx = abs(2 * x - width)
            ny = abs(2 * y - height)
            shade = min(18, (nx + ny) * 18 // (width + height))
            px = blend(base, soft, shade)

            tx, ty = x % tile, y % tile
            cell = ((x // tile) + (y // tile)) % 4
            dot = (tx - 24) ** 2 + (ty - 28) ** 2 <= 5 ** 2
            ring_d2 = (tx - 86) ** 2 + (ty - 38) ** 2
            ring = 15 ** 2 <= ring_d2 <= 18 ** 2
            leaf = ((tx - 70) * 5 + (ty - 88) * 9) ** 2 <= 42 ** 2 and ((tx - 70) * 9 - (ty - 88) * 5) ** 2 <= 85 ** 2
            sprig = abs((tx - 36) * 2 - (ty - 94)) <= 1 and 28 <= tx <= 48 and 78 <= ty <= 110

            if dot:
                px = blend(px, yellow if cell == 0 else aqua, 30)
            elif ring:
                px = blend(px, aqua if cell in (0, 3) else yellow, 20)
            elif leaf:
                px = blend(px, hover, 22)
            elif sprig:
                px = blend(px, yellow, 14)

            grain = ((x * 17 + y * 29 + (x ^ y) * 3) & 3) - 1
            raw.extend(max(0, min(255, channel + grain)) for channel in px)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + png_chunk(b"IEND", b"")
    )


def read_primary_background() -> bytes:
    """Decode the tracked, text-safe botanical wallpaper source (PNG, base64)."""
    if not BACKGROUND_SOURCE.is_file():
        raise FileNotFoundError(f"Telegram background source not found: {BACKGROUND_SOURCE}")

    encoded = b"".join(BACKGROUND_SOURCE.read_bytes().split())
    try:
        data = base64.b64decode(encoded, validate=True)
    except (ValueError, base64.binascii.Error) as exc:
        raise ValueError(f"Invalid base64 Telegram background source: {BACKGROUND_SOURCE}") from exc

    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Decoded Telegram background is not PNG: {BACKGROUND_SOURCE}")
    return data


def build_archive(palette: str, background: bytes) -> bytes:
    buffer = BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        archive.writestr(zip_entry("colors.tdesktop-theme"), palette.encode())
        archive.writestr(zip_entry("background.png"), background)
    return buffer.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if generated Telegram files are stale")
    parser.add_argument("--stdout", action="store_true", help="print the generated palette instead of writing files")
    args = parser.parse_args()

    colors = load_colors()
    palette = apply_telegram_overrides(render(colors))
    if args.stdout:
        print(palette, end="")
        return 0

    primary_background = read_primary_background()
    backup_background = render_backup_background(colors)
    archive = build_archive(palette, primary_background)

    if args.check:
        stale = False
        if not PALETTE_OUTPUT.exists() or PALETTE_OUTPUT.read_text() != palette:
            print(f"stale generated Telegram palette: {PALETTE_OUTPUT.relative_to(ROOT)}", file=sys.stderr)
            stale = True
        if not BACKGROUND_PRIMARY_OUTPUT.exists() or BACKGROUND_PRIMARY_OUTPUT.read_bytes() != primary_background:
            print(f"stale generated Telegram primary wallpaper: {BACKGROUND_PRIMARY_OUTPUT.relative_to(ROOT)}", file=sys.stderr)
            stale = True
        if not BACKGROUND_BACKUP_OUTPUT.exists() or BACKGROUND_BACKUP_OUTPUT.read_bytes() != backup_background:
            print(f"stale generated Telegram backup wallpaper: {BACKGROUND_BACKUP_OUTPUT.relative_to(ROOT)}", file=sys.stderr)
            stale = True
        if not OUTPUT.exists() or OUTPUT.read_bytes() != archive:
            print(f"stale generated Telegram archive: {OUTPUT.relative_to(ROOT)}", file=sys.stderr)
            stale = True
        return 1 if stale else 0

    PALETTE_OUTPUT.write_text(palette)
    BACKGROUND_PRIMARY_OUTPUT.write_bytes(primary_background)
    BACKGROUND_BACKUP_OUTPUT.write_bytes(backup_background)
    OUTPUT.write_bytes(archive)
    print(OUTPUT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
