#!/usr/bin/env python3
"""Block until no modifier key is physically held on any input device.

A script launched from a compositor keybinding starts while the binding's own
modifiers are still down. Synthetic Ctrl+A/Ctrl+C sent in that window arrive as
Super+Ctrl+A and the target application ignores them, so the capture silently
comes back empty. wtype cannot clear physical modifiers (xdotool's
--clearmodifiers has no Wayland equivalent), so the only fix is to wait.

Reads the kernel's live key state with EVIOCGKEY, which needs read access to
/dev/input/event* (group `input`). Exits 0 once idle, 2 on timeout, 3 when no
device could be read at all, so the caller can decide whether to go ahead.
"""

import fcntl
import glob
import os
import struct
import sys
import time

# linux/input-event-codes.h
MODIFIERS = (
    29,  # KEY_LEFTCTRL
    42,  # KEY_LEFTSHIFT
    54,  # KEY_RIGHTSHIFT
    56,  # KEY_LEFTALT
    97,  # KEY_RIGHTCTRL
    100,  # KEY_RIGHTALT
    125,  # KEY_LEFTMETA
    126,  # KEY_RIGHTMETA
)

KEY_MAX = 767
NBYTES = (KEY_MAX + 1) // 8
# EVIOCGKEY(len) = _IOR('E', 0x18, len)
EVIOCGKEY = (2 << 30) | (NBYTES << 16) | (ord("E") << 8) | 0x18


def held_modifiers(fd):
    buf = bytearray(NBYTES)
    fcntl.ioctl(fd, EVIOCGKEY, buf, True)
    return [code for code in MODIFIERS if buf[code // 8] >> (code % 8) & 1]


def main():
    timeout = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
    deadline = time.monotonic() + timeout
    readable = False

    while True:
        held = set()
        readable = False
        for path in sorted(glob.glob("/dev/input/event*")):
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            except OSError:
                continue
            try:
                held.update(held_modifiers(fd))
                readable = True
            except OSError:
                pass
            finally:
                os.close(fd)

        if not readable:
            return 3
        if not held:
            return 0
        if time.monotonic() >= deadline:
            return 2
        time.sleep(0.01)


if __name__ == "__main__":
    sys.exit(main())
