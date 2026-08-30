#!/usr/bin/env python3
"""Copy the tracked modular Quickshell config to its runtime cache."""

from pathlib import Path
import os
import shutil

ROOT = Path(__file__).resolve().parent
HOME = Path.home()
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache"))
OUT_DIR = CACHE_HOME / "dots-shell/quickshell"

OUT_DIR.mkdir(parents=True, exist_ok=True)
for name in ("components", "config", "services"):
    target = OUT_DIR / name
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(ROOT / name, target)
shutil.copy2(ROOT / "shell.qml", OUT_DIR / "shell.qml")
print(OUT_DIR)
