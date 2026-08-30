#!/usr/bin/env python3
"""Push Hyprland keyboard-layout events directly into Quickshell."""

from __future__ import annotations

import json
import os
import socket
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


def current_layout() -> tuple[str, str]:
    try:
        result = subprocess.run(
            ["hyprctl", "-j", "devices"],
            text=True,
            capture_output=True,
            timeout=1,
            check=False,
        )
        if result.returncode != 0:
            return "", ""
        keyboards = json.loads(result.stdout).get("keyboards", [])
        for keyboard in keyboards:
            if keyboard.get("main"):
                return str(keyboard.get("name", "")), str(keyboard.get("active_keymap", ""))
        if keyboards:
            return str(keyboards[0].get("name", "")), str(keyboards[0].get("active_keymap", ""))
    except Exception:
        pass
    return "", ""


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


def socket_candidates() -> list[Path]:
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    roots = [runtime / "hypr", Path("/tmp/hypr")]
    candidates: list[Path] = []
    if signature:
        candidates.extend(root / signature / ".socket2.sock" for root in roots)
    for root in roots:
        if root.exists():
            candidates.extend(root.glob("*/.socket2.sock"))
    seen: set[Path] = set()
    return [path for path in candidates if not (path in seen or seen.add(path))]


def event_socket() -> Path | None:
    for path in socket_candidates():
        if path.exists():
            return path
    return None


def listen() -> None:
    main_keyboard, layout = current_layout()
    if layout:
        publish_layout(layout)

    while True:
        path = event_socket()
        if path is None:
            time.sleep(0.5)
            continue

        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(str(path))
                stream = sock.makefile("r", encoding="utf-8", errors="replace")
                for raw in stream:
                    line = raw.rstrip("\n")
                    if not line.startswith("activelayout>>"):
                        continue
                    payload = line.split(">>", 1)[1]
                    keyboard, sep, next_layout = payload.partition(",")
                    if not sep:
                        continue
                    if main_keyboard and keyboard and keyboard != main_keyboard:
                        continue
                    publish_layout(next_layout)
        except (OSError, ValueError) as exc:
            print(f"layout-osd: Hyprland event socket reconnect: {exc}", flush=True)
            main_keyboard, layout = current_layout()
            if layout:
                publish_layout(layout)
            time.sleep(0.5)


def main() -> None:
    listen()


if __name__ == "__main__":
    main()
