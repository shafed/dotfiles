#!/usr/bin/env python3
"""Apply managed settings and the generated theme to CopyQ's live config.

CopyQ has no external-theme-file reference at runtime: [Theme] lives inline in
copyq.conf, normally populated by hand ("Load theme" in Preferences). This does
the same merge from the CLI, but only rewrites [Theme]'s key=value lines in
place. It also enforces the small set of behavior options owned by this repo;
everything else in copyq.conf (tabs, items, shortcuts, window geometry) is
left untouched.

copyq.conf is live, mutable app state, so ~/.config/copyq is intentionally not
a tracked symlink like the other CONFIG_DIRS; re-run this (and restart
copyq.service) whenever colors.toml regenerates copyq/gruvbox.ini.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME_INI = ROOT / "copyq/gruvbox.ini"
CONF = Path.home() / ".config/copyq/copyq.conf"
MANAGED_OPTIONS = {"close_on_unfocus": "true"}


def parse_theme(text: str) -> dict[str, str]:
    """Parse INI theme file, handling multi-line CSS values."""
    values = {}
    current_key = None
    current_value_lines = []
    in_multiline = False

    for line in text.splitlines():
        stripped = line.strip()

        if in_multiline:
            current_value_lines.append(line)
            if stripped.endswith('"') and len(stripped) > 1:
                in_multiline = False
                values[current_key] = "\n".join(current_value_lines)
                current_key = None
                current_value_lines = []
            continue

        if not stripped or stripped.startswith("[") or stripped.startswith("#"):
            continue

        key, sep, value = stripped.partition("=")
        if not sep:
            continue

        key = key.strip()
        value = value.strip()

        if value.startswith('"') and not (value.endswith('"') and len(value) > 1):
            in_multiline = True
            current_key = key
            current_value_lines = [line]
        else:
            values[key] = value

    if current_key and current_value_lines:
        values[current_key] = "\n".join(current_value_lines)

    return values


def ensure_section(lines: list[str], name: str) -> int:
    """Return a section index, appending an empty section when CopyQ omitted it."""
    header = f"[{name}]"
    try:
        return lines.index(header)
    except ValueError:
        if lines and lines[-1] != "":
            lines.append("")
        lines.append(header)
        return len(lines) - 1


def section_end(lines: list[str], start: int) -> int:
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("["):
            return i
    return len(lines)


def existing_key_ranges(lines: list[str], start: int, end: int) -> dict[str, tuple[int, int]]:
    ranges: dict[str, tuple[int, int]] = {}
    i = start + 1
    while i < end:
        line = lines[i]
        if "=" not in line or line.startswith("["):
            i += 1
            continue

        key = line.split("=", 1)[0].strip()
        value_part = line.split("=", 1)[1].strip()
        if value_part.startswith('"') and not (value_part.endswith('"') and len(value_part) > 1):
            j = i + 1
            while j < end and not lines[j].strip().endswith('"'):
                j += 1
            ranges[key] = (i, min(j + 1, end))
            i = min(j + 1, end)
        else:
            ranges[key] = (i, i + 1)
            i += 1
    return ranges


def rendered_lines(values: dict[str, str]) -> list[str]:
    out: list[str] = []
    for key in sorted(values):
        value = values[key]
        if "\n" in value:
            out.extend(value.split("\n"))
        else:
            out.append(f"{key}={value}")
    return out


def replace_managed_keys(lines: list[str], section: str, values: dict[str, str]) -> list[str]:
    """Put managed keys directly after the section header in one stable layout."""
    start = ensure_section(lines, section)
    end = section_end(lines, start)
    ranges = existing_key_ranges(lines, start, end)

    remove = set()
    for key in values:
        if key not in ranges:
            continue
        first, last = ranges[key]
        remove.update(range(first, last))

    unmanaged_body = [lines[i] for i in range(start + 1, end) if i not in remove]
    return lines[: start + 1] + rendered_lines(values) + unmanaged_body + lines[end:]


def main() -> int:
    if not THEME_INI.exists():
        print(f"missing {THEME_INI}; run scripts/generate-theme.py first", file=sys.stderr)
        return 1
    if not CONF.exists():
        print(f"skipped CopyQ config: {CONF} does not exist yet")
        return 0

    theme = parse_theme(THEME_INI.read_text())
    lines = CONF.read_text().splitlines()
    lines = replace_managed_keys(lines, "Theme", theme)
    lines = replace_managed_keys(lines, "Options", MANAGED_OPTIONS)

    CONF.write_text("\n".join(lines) + "\n")
    print(
        f"applied {len(theme)} theme keys and {len(MANAGED_OPTIONS)} behavior option(s) to {CONF}"
    )
    print("restart copyq for it to take effect: dots restart copyq")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
