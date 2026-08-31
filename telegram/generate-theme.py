#!/usr/bin/env python3
"""Build Telegram Desktop day/night themes and the live darkman target."""

from __future__ import annotations

import argparse
import base64
from io import BytesIO
import os
from pathlib import Path
import struct
import subprocess
import sys
import zipfile
import zlib

from _palette_renderer import load_colors, render

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
BACKGROUND_SOURCE = HERE / "background.png.b64"
BACKGROUND_PRIMARY_OUTPUT = HERE / "background-primary.png"
BACKGROUND_BACKUP_OUTPUT = HERE / "background-backup.png"
DAY_PALETTE_OUTPUT = HERE / "colors-day.tdesktop-theme"
NIGHT_PALETTE_OUTPUT = HERE / "colors-night.tdesktop-theme"
DAY_OUTPUT = HERE / "gruvbox-material-day.tdesktop-theme"
NIGHT_OUTPUT = HERE / "gruvbox-material-night.tdesktop-theme"
LEGACY_OUTPUT = HERE / "gruvbox-material-dark-medium.tdesktop-theme"

DAY_ALIASES = {
    "GB_BG_HARD": "#34352f",
    "GB_BG": "#41423b",
    "GB_BG_ALT": "#4b4c44",
    "GB_BG_SOFT": "#55564d",
    "GB_BG_HOVER": "#626358",
    "GB_BG_MUTED": "#747568",
    "GB_FG": "#f3f0e6",
    "GB_FG_UI": "#fffaf0",
    "GB_FG_BRIGHT": "#fffaf0",
    "GB_FG_SOFT": "#d8d4c8",
    "GB_GRAY": "#9f9d94",
    "GB_GRAY_DIM": "#c2beb2",
    "GB_RED": "#df735d",
    "GB_GREEN": "#a3ad72",
    "GB_YELLOW": "#e2b65f",
    "GB_ORANGE": "#ee8156",
    "GB_BLUE": "#7ba6a0",
    "GB_PURPLE": "#b78d9b",
    "GB_AQUA": "#79b4a4",
}

DAY_REPLACEMENTS = {
    "msgInBg: GB_BG_HARD;": "msgInBg: #41423b;",
    "msgInBgSelected: GB_BG_HOVER;": "msgInBgSelected: #55564d;",
    "msgOutBg: GB_BG_SOFT;": "msgOutBg: #5b5c52;",
    "msgOutBgSelected: GB_BG_MUTED;": "msgOutBgSelected: #6b6c60;",
    "msgServiceBg: #1d2021cc;": "msgServiceBg: #41423bf0;",
    "msgServiceBgSelected: #504945dd;": "msgServiceBgSelected: #55564df0;",
    "historySystemBg: #1d2021cc;": "historySystemBg: #41423bf0;",
    "historySystemBgSelected: #504945dd;": "historySystemBgSelected: #55564df0;",
    "historyForwardChooseBg: #1d2021aa;": "historyForwardChooseBg: #34352fcc;",
    "historyScrollBgOver: #50494555;": "historyScrollBgOver: #62635866;",
    "videoPlayIconBg: #1d2021cc;": "videoPlayIconBg: #34352fcc;",
    "toastBg: #1d2021e8;": "toastBg: #34352ff0;",
    "msgSelectOverlay: #d8a6574c;": "msgSelectOverlay: #e2b65f4c;",
    "msgStickerOverlay: #d8a65740;": "msgStickerOverlay: #e2b65f40;",
    "overviewPhotoSelectOverlay: #d8a65740;": "overviewPhotoSelectOverlay: #e2b65f40;",
    "historyScrollBarBg: #a8998466;": "historyScrollBarBg: #c2beb266;",
    "historyScrollBarBgOver: #d4be9899;": "historyScrollBarBgOver: #fffaf099;",
    "scrollBarBg: #a8998466;": "scrollBarBg: #c2beb266;",
    "scrollBarBgOver: #d4be9899;": "scrollBarBgOver: #fffaf099;",
    "scrollBgOver: #50494555;": "scrollBgOver: #62635866;",
}

# The base renderer was tuned for daylight before day/night variants existed.
# Restore the original Gruvbox Material Dark chat semantics only for night so
# bright daytime text and darker daylight bubbles do not leak into dark mode.
NIGHT_REPLACEMENTS = {
    "historyTextInFg: GB_FG_BRIGHT;": "historyTextInFg: GB_FG;",
    "historyTextOutFg: GB_FG_BRIGHT;": "historyTextOutFg: GB_FG;",
    "msgInBg: GB_BG_HARD;": "msgInBg: GB_BG_ALT;",
    "msgInDateFg: GB_FG_SOFT;": "msgInDateFg: GB_GRAY_DIM;",
    "msgInDateFgSelected: GB_FG_BRIGHT;": "msgInDateFgSelected: GB_FG_SOFT;",
    "msgOutDateFg: GB_FG_SOFT;": "msgOutDateFg: GB_GRAY_DIM;",
    "msgOutDateFgSelected: GB_FG_BRIGHT;": "msgOutDateFgSelected: GB_FG_SOFT;",
}

COMMON_OVERRIDES = """

// Telegram folder sidebar.
sideBarBg: GB_BG_HARD;
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
// the same accent as a necessary limitation of the theme format.
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


def zip_entry(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    return info


def replace_once(palette: str, old: str, new: str, context: str) -> str:
    if old not in palette:
        raise ValueError(f"Telegram {context} replacement anchor not found: {old}")
    return palette.replace(old, new, 1)


def apply_day_palette(palette: str) -> str:
    """Move the whole Telegram UI into the muted sunrise olive/taupe range."""
    for name, value in DAY_ALIASES.items():
        prefix = f"{name}: "
        start = palette.find(prefix)
        if start < 0:
            raise ValueError(f"Telegram day palette alias not found: {name}")
        end = palette.find(";", start)
        if end < 0:
            raise ValueError(f"Telegram day palette alias is malformed: {name}")
        palette = palette[:start] + f"{name}: {value}" + palette[end:]

    for old, new in DAY_REPLACEMENTS.items():
        palette = replace_once(palette, old, new, "daylight")
    return palette


def apply_night_palette(palette: str) -> str:
    """Restore the original warm Gruvbox Material Dark chat treatment."""
    for old, new in NIGHT_REPLACEMENTS.items():
        palette = replace_once(palette, old, new, "night")
    return palette


def apply_telegram_overrides(palette: str, variant: str = "night") -> str:
    """Apply the selected Telegram palette plus Telegram-only semantic keys."""
    if variant == "day":
        palette = apply_day_palette(palette)
    elif variant == "night":
        palette = apply_night_palette(palette)
    else:
        raise ValueError(f"unknown Telegram theme variant: {variant}")

    marker = "\n// Generic scrollbars.\n"
    if marker not in palette:
        raise ValueError("Telegram palette insertion anchor not found")
    return palette.replace(marker, COMMON_OVERRIDES + marker, 1)


def render_variant(colors: dict[str, str], variant: str) -> str:
    return apply_telegram_overrides(render(colors), variant)


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


def runtime_path() -> Path:
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    return data_home / "dotfiles/telegram/current.tdesktop-theme"


def resolve_runtime_variant(value: str) -> str:
    if value in {"day", "light"}:
        return "day"
    if value in {"night", "dark"}:
        return "night"
    if value != "auto":
        raise ValueError(f"unknown Telegram runtime state: {value}")

    try:
        result = subprocess.run(
            ["darkman", "get"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return "night"
    return "day" if result.stdout.strip() == "light" else "night"


def write_runtime(archive: bytes, target: Path) -> bool:
    """Replace the watched theme atomically so Telegram never reads a partial zip."""
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.read_bytes() == archive:
        return False
    temporary = target.with_name(f".{target.name}.tmp")
    temporary.write_bytes(archive)
    os.replace(temporary, target)
    return True


def check_file(path: Path, expected: bytes | str, label: str) -> bool:
    actual = path.read_text() if isinstance(expected, str) and path.exists() else path.read_bytes() if path.exists() else None
    if actual == expected:
        return False
    print(f"stale generated Telegram {label}: {path.relative_to(ROOT)}", file=sys.stderr)
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if generated Telegram files are stale")
    parser.add_argument("--stdout", action="store_true", help="print one generated palette")
    parser.add_argument("--variant", choices=("day", "night"), default="day")
    parser.add_argument(
        "--runtime",
        choices=("auto", "light", "dark", "day", "night"),
        help="write the stable Telegram file watched by darkman/Telegram",
    )
    args = parser.parse_args()

    colors = load_colors()
    day_palette = render_variant(colors, "day")
    night_palette = render_variant(colors, "night")

    if args.stdout:
        print(day_palette if args.variant == "day" else night_palette, end="")
        return 0

    primary_background = read_primary_background()

    if args.runtime:
        variant = resolve_runtime_variant(args.runtime)
        palette = day_palette if variant == "day" else night_palette
        target = runtime_path()
        changed = write_runtime(build_archive(palette, primary_background), target)
        print(f"{target} ({variant}{', updated' if changed else ', unchanged'})")
        return 0

    backup_background = render_backup_background(colors)
    day_archive = build_archive(day_palette, primary_background)
    night_archive = build_archive(night_palette, primary_background)

    generated = (
        (DAY_PALETTE_OUTPUT, day_palette, "day palette"),
        (NIGHT_PALETTE_OUTPUT, night_palette, "night palette"),
        (BACKGROUND_PRIMARY_OUTPUT, primary_background, "primary wallpaper"),
        (BACKGROUND_BACKUP_OUTPUT, backup_background, "backup wallpaper"),
        (DAY_OUTPUT, day_archive, "day archive"),
        (NIGHT_OUTPUT, night_archive, "night archive"),
        (LEGACY_OUTPUT, night_archive, "legacy night archive"),
    )

    if args.check:
        return 1 if any(check_file(path, expected, label) for path, expected, label in generated) else 0

    for path, content, _label in generated:
        if isinstance(content, str):
            path.write_text(content)
        else:
            path.write_bytes(content)
    print(DAY_OUTPUT.relative_to(ROOT))
    print(NIGHT_OUTPUT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
