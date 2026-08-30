#!/usr/bin/env python3
"""Push backlight changes directly into Quickshell."""

from __future__ import annotations

import os
import subprocess
import time
from pathlib import Path

HOME = Path.home()
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache"))
SHELL_PATH = CACHE_HOME / "dots-shell/quickshell"
BACKLIGHT_ROOT = Path("/sys/class/backlight")


def brightness_percent() -> int | None:
    try:
        devices = sorted(BACKLIGHT_ROOT.iterdir())
    except OSError:
        return None
    for device in devices:
        try:
            value = int((device / "brightness").read_text().strip())
            maximum = int((device / "max_brightness").read_text().strip())
            if maximum > 0:
                return max(0, min(100, round(value * 100 / maximum)))
        except (OSError, ValueError):
            continue
    return None


def publish(value: int, notify: bool) -> None:
    try:
        subprocess.run(
            [
                "quickshell", "ipc", "-p", str(SHELL_PATH),
                "call", "dots", "brightnessChanged", str(value), "1" if notify else "0",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1,
            check=False,
        )
    except subprocess.SubprocessError:
        pass


def main() -> None:
    last = brightness_percent()
    if last is not None:
        publish(last, False)
    while True:
        time.sleep(0.1 if last is not None else 2.0)
        value = brightness_percent()
        if value is not None and value != last:
            publish(value, last is not None)
        last = value


if __name__ == "__main__":
    main()
