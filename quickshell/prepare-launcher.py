#!/usr/bin/env python3
"""Add standalone Applications and Bookmarks pickers to generated Quickshell."""

from pathlib import Path
import shutil
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: prepare-launcher.py <runtime-dir>")

ROOT = Path(__file__).resolve().parent
RUNTIME = Path(sys.argv[1]).resolve()
SHELL = RUNTIME / "shell.qml"
APPLICATIONS_COMPONENT = ROOT / "DesktopLauncher.qml"
BOOKMARKS_COMPONENT = ROOT / "BookmarksPicker.qml"

text = SHELL.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise RuntimeError(f"prepare-launcher.py: missing expected {label} block")
    text = text.replace(old, new, 1)


replace_once(
    "  property var notificationRefs: ({})\n",
    "  property var notificationRefs: ({})\n\n"
    "  DesktopLauncher { id: desktopLauncher }\n"
    "  BookmarksPicker { id: bookmarksPicker }\n",
    "picker insertion point",
)

replace_once(
    "  function togglePanel(name) {\n"
    "    if (!laptop && (name === \"network\" || name === \"bluetooth\")) return\n",
    "  function togglePanel(name) {\n"
    "    if (!laptop && (name === \"network\" || name === \"bluetooth\")) return\n"
    "    desktopLauncher.close()\n"
    "    bookmarksPicker.close()\n"
    "    clipboardOpen = false\n",
    "panel toggle",
)

replace_once(
    "  IpcHandler {\n"
    "    target: \"dots\"\n"
    "    function toggleClipboard(): string {\n"
    "      root.clipboardOpen = !root.clipboardOpen\n",
    "  IpcHandler {\n"
    "    target: \"dots\"\n"
    "    function closeOverlays(): string {\n"
    "      root.openPanel = \"\"\n"
    "      root.clipboardOpen = false\n"
    "      return \"ok\"\n"
    "    }\n"
    "    function toggleClipboard(): string {\n"
    "      desktopLauncher.close()\n"
    "      bookmarksPicker.close()\n"
    "      root.openPanel = \"\"\n"
    "      root.clipboardOpen = !root.clipboardOpen\n",
    "overlay IPC",
)

SHELL.write_text(text)
shutil.copy2(APPLICATIONS_COMPONENT, RUNTIME / APPLICATIONS_COMPONENT.name)
shutil.copy2(BOOKMARKS_COMPONENT, RUNTIME / BOOKMARKS_COMPONENT.name)
