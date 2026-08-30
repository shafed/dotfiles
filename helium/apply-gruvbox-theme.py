#!/usr/bin/env python3
"""Install an exact Gruvbox Chromium theme for Helium on Arch Linux."""

from __future__ import annotations

import argparse
import json
import os
import shutil
from pathlib import Path
import tomllib

ROOT = Path(__file__).resolve().parent.parent
PALETTE = ROOT / "colors.toml"
MANAGED_START = "# >>> dotfiles: helium gruvbox >>>"
MANAGED_END = "# <<< dotfiles: helium gruvbox <<<"
THEME_VERSION_MAJOR = 2
OLD_THEME_MARKERS = (
    "helium-gruvbox-theme",
    "/helium/gruvbox-material",
    "/dotfiles/helium-gruvbox",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate and configure the repo's exact Gruvbox theme for Helium."
    )
    parser.add_argument(
        "--config-home",
        type=Path,
        help="override XDG_CONFIG_HOME (default: environment or ~/.config)",
    )
    parser.add_argument(
        "--data-home",
        type=Path,
        help="override XDG_DATA_HOME (default: environment or ~/.local/share)",
    )
    return parser.parse_args()


def load_colors() -> dict[str, str]:
    with PALETTE.open("rb") as handle:
        data = tomllib.load(handle)
    colors = data.get("colors")
    if not isinstance(colors, dict):
        raise ValueError(f"missing [colors] in {PALETTE}")
    required = (
        "bg_hard",
        "bg",
        "bg_alt",
        "bg_soft",
        "fg",
        "gray",
        "gray_dim",
        "blue",
    )
    for name in required:
        value = colors.get(name)
        if (
            not isinstance(value, str)
            or len(value) != 7
            or not value.startswith("#")
        ):
            raise ValueError(f"invalid colors.{name} in {PALETTE}: {value!r}")
    return colors


def rgb(value: str) -> list[int]:
    value = value.removeprefix("#")
    return [int(value[index : index + 2], 16) for index in (0, 2, 4)]


def theme_payload(colors: dict[str, str]) -> dict[str, object]:
    # Keep the chrome hierarchy simple: all passive/background surfaces use the
    # darkest Gruvbox background, while the active tab gets the lighter surface.
    # For a third-party theme Chromium's generic tab mixer maps toolbar to the
    # active tab and background_tab to inactive tabs/New Tab.
    theme_colors = {
        "frame": rgb(colors["bg_hard"]),
        "frame_inactive": rgb(colors["bg_hard"]),
        "toolbar": rgb(colors["bg_soft"]),
        "background_tab": rgb(colors["bg_hard"]),
        "background_tab_inactive": rgb(colors["bg_hard"]),
        "tab_text": rgb(colors["fg"]),
        "tab_background_text": rgb(colors["gray_dim"]),
        "tab_background_text_inactive": rgb(colors["gray"]),
        "bookmark_text": rgb(colors["fg"]),
        "toolbar_text": rgb(colors["fg"]),
        "toolbar_button_icon": rgb(colors["fg"]),
        "button_background": rgb(colors["bg_hard"]),
        "omnibox_background": rgb(colors["bg_hard"]),
        "omnibox_text": rgb(colors["fg"]),
        "ntp_background": rgb(colors["bg_hard"]),
        "ntp_header": rgb(colors["bg_alt"]),
        "ntp_text": rgb(colors["fg"]),
        "ntp_link": rgb(colors["blue"]),
    }
    # Identity tints keep Chromium from hue-shifting any fallback surfaces. In
    # particular, background_tab must stay the exact frame color when a fallback
    # path is used rather than a generated Material shade.
    identity_tint = [-1, -1, -1]
    return {
        "colors": theme_colors,
        "tints": {
            "background_tab": identity_tint,
            "buttons": identity_tint,
            "frame": identity_tint,
            "frame_inactive": identity_tint,
            "frame_incognito": identity_tint,
            "frame_incognito_inactive": identity_tint,
        },
        "properties": {"ntp_logo_alternate": 1},
    }


def parse_managed_version(value: object) -> tuple[int, int, int, int] | None:
    if not isinstance(value, str):
        return None
    parts = value.split(".")
    if not 1 <= len(parts) <= 4:
        return None
    try:
        numbers = [int(part) for part in parts]
    except ValueError:
        return None
    if any(number < 0 or number > 65535 for number in numbers):
        return None
    numbers.extend([0] * (4 - len(numbers)))
    return tuple(numbers)  # type: ignore[return-value]


def bump_managed_version(version: tuple[int, int, int, int] | None) -> str:
    if version is None or version[0] != THEME_VERSION_MAJOR:
        return f"{THEME_VERSION_MAJOR}.0.0.1"

    major, high, middle, low = version
    low += 1
    if low > 65535:
        low = 0
        middle += 1
    if middle > 65535:
        middle = 0
        high += 1
    if high > 65535:
        raise ValueError("Helium theme version counter exhausted")
    return f"{major}.{high}.{middle}.{low}"


def choose_manifest_version(manifest_path: Path, theme: dict[str, object]) -> str:
    # ThemeService does not re-apply a loaded theme when the same extension ID is
    # already current. A real extension update does, so bump the unpacked theme
    # version only when its generated theme payload changes. This is the
    # programmatic equivalent of pressing Reload on chrome://extensions.
    if not manifest_path.exists():
        return f"{THEME_VERSION_MAJOR}.0.0.1"

    try:
        previous = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError):
        return f"{THEME_VERSION_MAJOR}.0.0.1"
    if not isinstance(previous, dict):
        return f"{THEME_VERSION_MAJOR}.0.0.1"

    previous_version = parse_managed_version(previous.get("version"))
    if previous.get("theme") == theme and previous_version is not None:
        if previous_version[0] == THEME_VERSION_MAJOR:
            return ".".join(str(part) for part in previous_version)
    return bump_managed_version(previous_version)


def render_manifest(colors: dict[str, str], manifest_path: Path) -> str:
    theme = theme_payload(colors)
    manifest = {
        "manifest_version": 3,
        "name": "Gruvbox Material Dark Medium — dotfiles",
        "version": choose_manifest_version(manifest_path, theme),
        "description": "Generated from dotfiles/colors.toml for Helium.",
        "theme": theme,
    }
    return json.dumps(manifest, indent=2) + "\n"


def strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def valid_extension_dir(value: str) -> bool:
    # Relative paths are resolved from Helium's launcher working directory and
    # can become '.', producing the misleading "Manifest missing" startup
    # dialog. Persistent flags should only contain real absolute extension dirs.
    path = Path(value)
    return path.is_absolute() and path.is_dir() and (path / "manifest.json").is_file()


def update_flags(flags_path: Path, theme_dir: Path) -> list[str]:
    if flags_path.is_symlink():
        target = os.readlink(flags_path)
        if "/helium/helium-browser-flags.conf" in target:
            flags_path.unlink()
        else:
            raise RuntimeError(
                f"refusing to replace user-managed symlink {flags_path} -> {target}"
            )

    original = flags_path.read_text() if flags_path.exists() else ""
    backup = flags_path.with_suffix(flags_path.suffix + ".gruvbox-backup")
    if original and not backup.exists():
        shutil.copy2(flags_path, backup)

    output: list[str] = []
    load_extensions: list[str] = []
    dropped: list[str] = []
    in_managed_block = False

    for line in original.splitlines():
        stripped = line.strip()
        if stripped == MANAGED_START:
            in_managed_block = True
            continue
        if stripped == MANAGED_END:
            in_managed_block = False
            continue
        if in_managed_block:
            continue

        if stripped.startswith("--load-extension="):
            value = strip_quotes(stripped.split("=", 1)[1])
            for entry in value.split(","):
                entry = strip_quotes(entry.strip())
                if not entry:
                    continue
                if any(marker in entry for marker in OLD_THEME_MARKERS):
                    continue
                if not valid_extension_dir(entry):
                    dropped.append(entry)
                    continue
                if entry not in load_extensions:
                    load_extensions.append(entry)
            continue

        output.append(line)

    theme_path = str(theme_dir.resolve())
    if not valid_extension_dir(theme_path):
        raise RuntimeError(f"generated theme is missing a readable manifest: {theme_path}")
    if theme_path not in load_extensions:
        load_extensions.append(theme_path)

    while output and not output[-1].strip():
        output.pop()
    if output:
        output.append("")
    output.extend(
        [
            MANAGED_START,
            # helium-browser-bin's Arch wrapper parses one argument per line.
            # The managed data path has no shell expansion and is absolute.
            f'--load-extension={",".join(load_extensions)}',
            MANAGED_END,
            "",
        ]
    )

    flags_path.parent.mkdir(parents=True, exist_ok=True)
    flags_path.write_text("\n".join(output))
    return dropped


def cleanup_old_theme_link(config_home: Path) -> None:
    old_link = config_home / "helium-gruvbox-theme"
    if not old_link.is_symlink():
        return
    target = os.readlink(old_link)
    if "helium/gruvbox-material" in target:
        old_link.unlink()


def main() -> int:
    args = parse_args()
    config_home = (
        args.config_home.expanduser()
        if args.config_home
        else Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    )
    data_home = (
        args.data_home.expanduser()
        if args.data_home
        else Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    )
    theme_dir = data_home / "dotfiles" / "helium-gruvbox"
    flags_path = config_home / "helium-browser-flags.conf"

    try:
        colors = load_colors()
        theme_dir.mkdir(parents=True, exist_ok=True)
        manifest_path = theme_dir / "manifest.json"
        manifest_path.write_text(render_manifest(colors, manifest_path))
        # Read it back so a partial/corrupt write is caught before touching the
        # browser flags file.
        manifest = json.loads(manifest_path.read_text())
        if not isinstance(manifest.get("theme", {}).get("colors"), dict):
            raise ValueError(f"generated manifest has no theme colors: {manifest_path}")
        cleanup_old_theme_link(config_home)
        dropped = update_flags(flags_path, theme_dir)
    except (OSError, json.JSONDecodeError, ValueError, RuntimeError) as error:
        print(f"helium-gruvbox-theme: {error}")
        return 1

    print(f"Helium Gruvbox theme: {theme_dir}")
    print(f"Helium theme version: {manifest['version']}")
    print(f"Helium flags: {flags_path}")
    for entry in dropped:
        print(f"Dropped stale --load-extension entry: {entry}")
    print("Restart Helium completely to load the updated theme.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
