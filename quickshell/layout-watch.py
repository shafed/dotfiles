#!/usr/bin/env python3
"""Show the Quickshell OSD when Hyprland changes keyboard layout."""

from __future__ import annotations

import glob
import os
import socket
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


def socket_candidates() -> list[Path]:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    candidates: list[Path] = []

    if signature:
        candidates.extend([
            runtime / "hypr" / signature / ".socket2.sock",
            Path("/tmp/hypr") / signature / ".socket2.sock",
        ])

    for pattern in (
        str(runtime / "hypr" / "*" / ".socket2.sock"),
        "/tmp/hypr/*/.socket2.sock",
    ):
        candidates.extend(Path(path) for path in glob.glob(pattern))

    seen: set[Path] = set()
    return [path for path in candidates if not (path in seen or seen.add(path))]


def find_socket() -> Path | None:
    existing = [path for path in socket_candidates() if path.exists()]
    if not existing:
        return None
    return max(existing, key=lambda path: path.stat().st_mtime)


def show_layout(layout: str) -> None:
    label = layout_label(layout)
    if label == "--":
        return
    subprocess.run(
        [
            "quickshell", "ipc", "-p", str(SHELL_PATH),
            "call", "dots", "showOsd", "LANG", label, "0",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=2,
        check=False,
    )


def watch(path: Path) -> None:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(str(path))
        buffer = b""
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                return
            buffer += chunk
            while b"\n" in buffer:
                raw, buffer = buffer.split(b"\n", 1)
                line = raw.decode("utf-8", errors="replace")
                if not line.startswith("activelayout>>"):
                    continue
                payload = line.split(">>", 1)[1]
                _, separator, layout = payload.partition(",")
                if separator and layout:
                    show_layout(layout)


def main() -> None:
    while True:
        path = find_socket()
        if path is None:
            time.sleep(1)
            continue
        try:
            watch(path)
        except (OSError, subprocess.SubprocessError):
            time.sleep(0.5)


if __name__ == "__main__":
    main()
