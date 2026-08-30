#!/usr/bin/env python3
"""Show the Quickshell OSD and refresh the bar on keyboard layout changes."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path

HOME = Path.home()
SHELL_PATH = HOME / "github/dotfiles/quickshell"


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


def ipc_call(*args: str) -> bool:
    try:
        result = subprocess.run(
            [
                "quickshell", "ipc", "-p", str(SHELL_PATH),
                "call", "dots", *args,
            ],
            text=True,
            capture_output=True,
            timeout=1,
            check=False,
        )
    except subprocess.SubprocessError as exc:
        print(f"layout-osd: IPC failed: {exc}", flush=True)
        return False

    if result.returncode != 0:
        print(f"layout-osd: IPC failed: {result.stderr.strip()}", flush=True)
        return False
    return True


def publish_layout(layout: str) -> None:
    label = layout_label(layout)
    if label == "--":
        return

    # Do not wait for the shell's regular 800 ms fast-snapshot timer. Trigger
    # the same fast refresh immediately so the bar follows the real layout.
    ipc_call("refresh")
    ipc_call("showOsd", "LANG", label, "0")


def main() -> None:
    last = ""
    while True:
        layout = current_layout()
        if layout:
            if last and layout != last:
                publish_layout(layout)
            last = layout
        # A short fallback poll keeps this independent of Hyprland socket path
        # changes while remaining effectively instantaneous to the user.
        time.sleep(0.05)


if __name__ == "__main__":
    main()
