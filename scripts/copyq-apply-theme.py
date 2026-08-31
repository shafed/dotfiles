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


def main() -> int:
    if not THEME_INI.exists():
        print(f"missing {THEME_INI}; run scripts/generate-theme.py first", file=sys.stderr)
        return 1
    if not CONF.exists():
        print(f"skipped CopyQ config: {CONF} does not exist yet")
        return 0

    theme = parse_theme(THEME_INI.read_text())
    lines = CONF.read_text().splitlines()

    try:
        start = lines.index("[Theme]")
    except ValueError:
        print(f"{CONF} has no [Theme] section", file=sys.stderr)
        return 1
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("["):
            end = i
            break

    # First pass: collect which keys exist in the [Theme] section and their line ranges
    existing_keys: dict[str, tuple[int, int]] = {}  # key -> (start_line, end_line)
    i = start + 1
    while i < end:
        line = lines[i]
        if "=" in line and not line.startswith("["):
            key = line.split("=", 1)[0].strip()
            key_start = i
            # Check for multi-line value (starts with " and doesn't end with ")
            value_part = line.split("=", 1)[1].strip() if "=" in line else ""
            if value_part.startswith('"') and not (value_part.endswith('"') and len(value_part) > 1):
                # Multi-line: scan forward for closing quote
                j = i + 1
                while j < end and not lines[j].strip().endswith('"'):
                    j += 1
                existing_keys[key] = (key_start, j + 1)
                i = j + 1
            else:
                existing_keys[key] = (key_start, key_start + 1)
                i += 1
        else:
            i += 1

    # Remove existing keys that we're going to replace
    keys_to_remove = set(existing_keys.keys()) & set(theme.keys())
    lines_to_remove = set()
    for key in keys_to_remove:
        s, e = existing_keys[key]
        for ln in range(s, e):
            lines_to_remove.add(ln)
    new_lines = [ln for idx, ln in enumerate(lines) if idx not in lines_to_remove]

    # Recalculate end after removal
    end = len(new_lines)
    for i in range(start + 1, len(new_lines)):
        if new_lines[i].startswith("["):
            end = i
            break

    # Insert new/updated keys
    insert_at = end
    for key in sorted(theme.keys()):
        value = theme[key]
        if "\n" in value:
            # Multi-line value: insert each line separately
            for line in value.split("\n"):
                new_lines.insert(insert_at, line)
                insert_at += 1
        else:
            new_lines.insert(insert_at, f"{key}={value}")
            insert_at += 1

    try:
        options_start = new_lines.index("[Options]")
    except ValueError:
        print(f"{CONF} has no [Options] section", file=sys.stderr)
        return 1

    options_end = len(new_lines)
    for i in range(options_start + 1, len(new_lines)):
        if new_lines[i].startswith("["):
            options_end = i
            break

    for key, value in MANAGED_OPTIONS.items():
        prefix = f"{key}="
        for i in range(options_start + 1, options_end):
            if new_lines[i].startswith(prefix):
                new_lines[i] = f"{key}={value}"
                break
        else:
            new_lines.insert(options_end, f"{key}={value}")
            options_end += 1

    CONF.write_text("\n".join(new_lines) + "\n")
    print(
        f"applied {len(theme)} theme keys and {len(MANAGED_OPTIONS)} behavior option(s) to {CONF}"
    )
    print("restart copyq for it to take effect: dots restart copyq")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
