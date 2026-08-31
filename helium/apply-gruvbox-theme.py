#!/usr/bin/env python3
"""Configure Helium to load the exact Gruvbox theme with live solar reloads."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
SWITCHER = ROOT / "helium/switch-gruvbox-theme.py"
MANAGED_START = "# >>> dotfiles: helium gruvbox >>>"
MANAGED_END = "# <<< dotfiles: helium gruvbox <<<"
LEGACY_BLOCKS = (
    (MANAGED_START, MANAGED_END),
    ("# >>> dotfiles: helium adaptive theme >>>", "# <<< dotfiles: helium adaptive theme <<<"),
    (
        "# >>> dotfiles: helium web color-scheme >>>",
        "# <<< dotfiles: helium web color-scheme <<<",
    ),
)
LEGACY_FORCE_FLAGS = {"--force-light-mode", "--force-dark-mode"}
DOTFILES_THEME_MARKERS = (
    "helium-gruvbox-theme",
    "/helium/gruvbox-material",
    "/dotfiles/helium-gruvbox",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Install the exact Gruvbox Helium extension theme and a local CDP "
            "endpoint used only to reload that unpacked theme on darkman changes."
        )
    )
    parser.add_argument("--config-home", type=Path)
    parser.add_argument("--data-home", type=Path)
    return parser.parse_args()


def strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def wrapper_safe_path(path: str) -> str:
    """Protect home paths from helium-browser-bin's broken tilde sanitization."""
    home = str(Path.home())
    if path == home or path.startswith(home + "/"):
        parent = str(Path.home().parent).rstrip("/")
        return f"{parent}/./{Path.home().name}{path[len(home):]}"
    return path


def update_flags(flags_path: Path, runtime: Path) -> bool:
    if flags_path.is_symlink():
        target = os.readlink(flags_path)
        if "/helium/helium-browser-flags.conf" in target:
            flags_path.unlink()
        else:
            raise RuntimeError(
                f"refusing to replace user-managed symlink {flags_path} -> {target}"
            )

    original = flags_path.read_text() if flags_path.exists() else ""
    starts = {start: end for start, end in LEGACY_BLOCKS}
    ends = {end for _, end in LEGACY_BLOCKS}
    output: list[str] = []
    load_extensions: list[str] = []
    active_end: str | None = None
    debugging_port: str | None = None

    for line in original.splitlines():
        stripped = line.strip()
        if active_end is not None:
            if stripped == active_end:
                active_end = None
            continue
        if stripped in starts:
            active_end = starts[stripped]
            continue
        if stripped in ends or stripped in LEGACY_FORCE_FLAGS:
            continue

        if stripped.startswith("--load-extension="):
            raw = strip_quotes(stripped.split("=", 1)[1])
            for entry in raw.split(","):
                candidate = strip_quotes(entry.strip())
                if candidate and not any(marker in candidate for marker in DOTFILES_THEME_MARKERS):
                    load_extensions.append(candidate)
            continue
        if stripped.startswith("--remote-debugging-port="):
            # Respect an existing explicit debugging port. If none exists, the
            # managed block uses port 0 so Chromium publishes DevToolsActivePort.
            if debugging_port is None:
                debugging_port = stripped
            continue
        output.append(line)

    runtime_path = str(runtime.resolve())
    load_extensions.append(runtime_path)
    deduped: list[str] = []
    seen: set[str] = set()
    for path in load_extensions:
        normalized = os.path.normpath(os.path.expanduser(path))
        if normalized in seen:
            continue
        seen.add(normalized)
        deduped.append(path)

    while output and not output[-1].strip():
        output.pop()
    if output:
        output.append("")
    output.extend(
        [
            MANAGED_START,
            "--load-extension=" + ",".join(wrapper_safe_path(path) for path in deduped),
            debugging_port or "--remote-debugging-port=0",
            MANAGED_END,
            "",
        ]
    )
    rendered = "\n".join(output)
    if rendered == original:
        return False
    flags_path.parent.mkdir(parents=True, exist_ok=True)
    flags_path.write_text(rendered)
    return True


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
    runtime = data_home / "dotfiles/helium-gruvbox"
    flags = config_home / "helium-browser-flags.conf"

    try:
        flags_changed = update_flags(flags, runtime)
        command = [
            sys.executable,
            str(SWITCHER),
            "auto",
            "--config-home",
            str(config_home),
            "--data-home",
            str(data_home),
        ]
        result = subprocess.run(command, check=False, text=True)
        if result.returncode != 0:
            return result.returncode
    except (OSError, RuntimeError) as error:
        print(f"helium-gruvbox-theme: {error}", file=sys.stderr)
        return 1

    print(f"Helium flags: {flags} ({'updated' if flags_changed else 'unchanged'})")
    print("Restart Helium once after first setup; later darkman changes reload the exact theme live.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
