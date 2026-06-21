#!/usr/bin/env python3
"""Force the US xkb layout while kanata's symbol layers are active.

kanata emits the symbol layers (symbols / symbols2) as plain S-... keycodes,
which only produce the right characters on the US (index 0) xkb layout -- on the
RU/ЙЦУКЕН layout Shift+2 = " and so on. This daemon connects to kanata's TCP
server (kanata --port PORT), watches LayerChange events, and:

  - on entering a symbol layer: remembers the `kanata` device's current layout
    index and switches it to US (0);
  - on leaving back to a non-symbol layer: restores the remembered index.

Because layer enter/leave is driven by the chord press/release, the US layout is
active exactly while you hold s+d+f (or a+s+d+f), with no timers or per-key cost.

Run it after kanata (see hyprland.conf). Reconnects if kanata restarts.
"""

import json
import socket
import subprocess
import time

PORT = 5829
HOST = "127.0.0.1"
DEV = "kanata"
SYMBOL_LAYERS = {"symbols", "symbols2"}

saved_idx = None  # layout index to restore when leaving the symbol layers


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


def on_layer(name):
    global saved_idx
    if name in SYMBOL_LAYERS:
        if saved_idx is None:  # entering from a normal layer
            saved_idx = current_layout_index()
            if saved_idx != 0:
                hypr("switchxkblayout", DEV, "0")
    else:
        if saved_idx is not None:  # leaving back to a normal layer
            if saved_idx != 0:
                hypr("switchxkblayout", DEV, str(saved_idx))
            saved_idx = None


def run_once():
    with socket.create_connection((HOST, PORT), timeout=5) as sock:
        buf = b""
        for chunk in iter(lambda: sock.recv(4096), b""):
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                change = msg.get("LayerChange")
                if change and "new" in change:
                    on_layer(change["new"])


def main():
    while True:
        try:
            run_once()
        except (ConnectionRefusedError, OSError):
            pass  # kanata not up yet or restarted; retry
        time.sleep(1)


if __name__ == "__main__":
    main()
