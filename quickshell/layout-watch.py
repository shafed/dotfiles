#!/usr/bin/env python3
"""Push keyboard layout changes directly into the Quickshell bar and OSD."""

from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path

HOME = Path.home()
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache"))
SHELL_PATH = CACHE_HOME / "dots-shell/quickshell"


def layout_label(layout: str) -> str:
    value = layout.strip()
    lower = value.lower()
    if "russian" in lower or lower == "ru" or "рус" in lower:
        return "RU"
    if "english" in lower or lower in {"us", "en"}:
        return "EN"
    return value[:2].upper() if value else "--"


def current_layout() -> str:
    try:
        result = subprocess.run(
            ["hyprctl", "-j", "devices"],
            text=True,
            capture_output=True,
            timeout=1,
            check=False,
        )
        if result.returncode != 0:
            return ""
        payload = json.loads(result.stdout)
        keyboards = payload.get("keyboards", [])
        for keyboard in keyboards:
            if keyboard.get("main"):
                return str(keyboard.get("active_keymap", ""))
        if keyboards:
            return str(keyboards[0].get("active_keymap", ""))
    except Exception:
        pass
    return ""


def publish_layout(layout: str) -> None:
    label = layout_label(layout)
    if label == "--":
        return
    try:
        result = subprocess.run(
            [
                "quickshell", "ipc", "-p", str(SHELL_PATH),
                "call", "dots", "layoutChanged", label,
            ],
            text=True,
            capture_output=True,
            timeout=1,
            check=False,
        )
    except subprocess.SubprocessError as exc:
        print(f"layout-osd: IPC failed: {exc}", flush=True)
        return
    if result.returncode != 0:
        print(f"layout-osd: IPC failed: {result.stderr.strip()}", flush=True)


def main() -> None:
    last = ""
    while True:
        layout = current_layout()
        if layout:
            if last and layout != last:
                publish_layout(layout)
            last = layout
        time.sleep(0.05)


if __name__ == "__main__":
    main()
