#!/usr/bin/env python3
"""Push default-sink volume/mute changes into Quickshell."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import time
from pathlib import Path

HOME = Path.home()
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache"))
SHELL_PATH = CACHE_HOME / "dots-shell/quickshell"


def read_audio() -> tuple[int, bool] | None:
    try:
        result = subprocess.run(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            text=True,
            capture_output=True,
            timeout=1,
            check=False,
        )
    except subprocess.SubprocessError:
        return None
    if result.returncode != 0:
        return None
    match = re.search(r"Volume:\s*([0-9.]+)", result.stdout)
    if not match:
        return None
    volume = max(0, min(150, round(float(match.group(1)) * 100)))
    return volume, "[MUTED]" in result.stdout


def publish(state: tuple[int, bool], notify: bool) -> None:
    volume, muted = state
    try:
        subprocess.run(
            [
                "quickshell", "ipc", "-p", str(SHELL_PATH),
                "call", "dots", "audioChanged",
                str(volume), "1" if muted else "0", "1" if notify else "0",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1,
            check=False,
        )
    except subprocess.SubprocessError:
        pass


def monitor_command() -> list[str] | None:
    if shutil.which("pactl"):
        return ["pactl", "subscribe"]
    if shutil.which("pw-dump"):
        return ["pw-dump", "-m", "-N"]
    return None


def run_monitor(last: tuple[int, bool] | None) -> tuple[int, bool] | None:
    command = monitor_command()
    if command is None:
        while True:
            time.sleep(0.15)
            state = read_audio()
            if state is not None and state != last:
                publish(state, last is not None)
                last = state

    try:
        process = subprocess.Popen(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=1,
        )
    except OSError:
        time.sleep(1)
        return last

    assert process.stdout is not None
    ignore_until = time.monotonic() + (0.4 if command[0] == "pw-dump" else 0.0)
    last_check = 0.0
    for line in process.stdout:
        if command[0] == "pactl":
            lower = line.lower()
            if "sink" not in lower and "server" not in lower:
                continue
        now = time.monotonic()
        if now < ignore_until or now - last_check < 0.04:
            continue
        last_check = now
        time.sleep(0.02)
        state = read_audio()
        if state is not None and state != last:
            publish(state, last is not None)
            last = state

    process.wait(timeout=1)
    return last


def main() -> None:
    last = read_audio()
    if last is not None:
        publish(last, False)
    while True:
        last = run_monitor(last)
        time.sleep(0.5)


if __name__ == "__main__":
    main()
