#!/usr/bin/env python3
"""Read/update application-launch counts shared with the former apps.sh QAT."""
from __future__ import annotations

import json
import sys
from pathlib import Path

USAGE_FILE = Path.home() / ".cache/apps-fzf/usage.tsv"


def normalize(value: str) -> str:
    value = value.strip()
    if value.lower().endswith(".desktop"):
        value = value[:-8]
    return value.lower()


def read_usage() -> dict[str, int]:
    result: dict[str, int] = {}
    try:
        for line in USAGE_FILE.read_text(errors="ignore").splitlines():
            app_id, sep, count = line.partition("\t")
            if not sep:
                continue
            try:
                result[normalize(app_id)] = max(result.get(normalize(app_id), 0), int(count))
            except ValueError:
                continue
    except OSError:
        pass
    return result


def write_usage(values: dict[str, int]) -> None:
    USAGE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = USAGE_FILE.with_suffix(".tmp")
    # Keep the historical apps.sh format so switching back remains lossless.
    rows = [f"{app_id}.desktop\t{count}" for app_id, count in sorted(values.items()) if app_id]
    tmp.write_text("\n".join(rows) + ("\n" if rows else ""))
    tmp.replace(USAGE_FILE)


def main() -> None:
    values = read_usage()
    if len(sys.argv) >= 3 and sys.argv[1] == "record":
        app_id = normalize(sys.argv[2])
        if app_id:
            values[app_id] = values.get(app_id, 0) + 1
            write_usage(values)
    print(json.dumps(values, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
