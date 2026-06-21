#!/usr/bin/env python3
"""Force the US xkb layout while kanata's symbol layers are active.

This script has two modes:

  symlayout-watch.py enter
  symlayout-watch.py leave

The enter/leave mode is intended to be called directly by kanata actions, so it
does not require kanata's TCP server.
"""

import json
import os
import subprocess
import sys

DEV = "kanata"
STATE_FILE = f"/tmp/symlayout-watch-{os.getuid()}-{DEV}.layout"


def hypr(*args):
    subprocess.run(
        ["hyprctl", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )


def current_layout_index():
    try:
        out = subprocess.run(
            ["hyprctl", "-j", "devices"], capture_output=True, text=True, timeout=1
        ).stdout
        data = json.loads(out)
        for kb in data.get("keyboards", []):
            if kb.get("name") == DEV:
                return int(kb.get("active_layout_index", 0))
    except Exception:
        pass
    return 0


def enter_symbol_layer():
    if os.path.exists(STATE_FILE):
        return

    idx = current_layout_index()
    with open(STATE_FILE, "w", encoding="utf-8") as state:
        state.write(str(idx))

    if idx != 0:
        hypr("switchxkblayout", DEV, "0")


def leave_symbol_layer():
    try:
        with open(STATE_FILE, encoding="utf-8") as state:
            idx = int(state.read().strip() or "0")
    except (FileNotFoundError, ValueError):
        return
    finally:
        try:
            os.unlink(STATE_FILE)
        except FileNotFoundError:
            pass

    if idx != 0:
        hypr("switchxkblayout", DEV, str(idx))


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"enter", "leave"}:
        raise SystemExit(f"usage: {sys.argv[0]} enter|leave")

    if sys.argv[1] == "enter":
        enter_symbol_layer()
    else:
        leave_symbol_layer()


if __name__ == "__main__":
    main()
