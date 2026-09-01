#!/usr/bin/env python3
"""Build Telegram Desktop day/night themes and the live darkman target."""

from __future__ import annotations

import argparse
from io import BytesIO
import os
from pathlib import Path
import subprocess
import sys
import zipfile

from _palette_renderer import load_colors, render

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
BACKGROUND_SOURCE = HERE / "background.png"
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
    "historyComposeAreaFg: GB_FG;": "historyComposeAreaFg: GB_FG_UI;",
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


def read_background() -> bytes:
    """Read the tracked PNG that is embedded directly into both Telegram themes."""
    if not BACKGROUND_SOURCE.is_file():
        raise FileNotFoundError(f"Telegram background source not found: {BACKGROUND_SOURCE}")

    data = BACKGROUND_SOURCE.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Telegram background source is not PNG: {BACKGROUND_SOURCE}")
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
    """Write the runtime theme used by direct generator invocations."""
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

    background = read_background()

    if args.runtime:
        variant = resolve_runtime_variant(args.runtime)
        palette = day_palette if variant == "day" else night_palette
        target = runtime_path()
        changed = write_runtime(build_archive(palette, background), target)
        print(f"{target} ({variant}{', updated' if changed else ', unchanged'})")
        return 0

    day_archive = build_archive(day_palette, background)
    night_archive = build_archive(night_palette, background)

    generated = (
        (DAY_PALETTE_OUTPUT, day_palette, "day palette"),
        (NIGHT_PALETTE_OUTPUT, night_palette, "night palette"),
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
