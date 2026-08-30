#!/usr/bin/env python3
"""Add standalone pickers and the compact system overview to generated Quickshell."""

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
    "    function toggleSystem(): string {\n"
    "      root.togglePanel(\"system\")\n"
    "      return root.openPanel === \"system\" ? \"open\" : \"closed\"\n"
    "    }\n"
    "    function toggleClipboard(): string {\n"
    "      desktopLauncher.close()\n"
    "      bookmarksPicker.close()\n"
    "      root.openPanel = \"\"\n"
    "      root.clipboardOpen = !root.clipboardOpen\n",
    "overlay IPC",
)

replace_once(
    "          sourceComponent: root.openPanel === \"audio\" ? audioPanel :\n",
    "          sourceComponent: root.openPanel === \"system\" ? systemPanel :\n"
    "                           root.openPanel === \"audio\" ? audioPanel :\n",
    "system panel loader",
)

replace_once(
    "  Component {\n"
    "    id: audioPanel\n",
    "  Component {\n"
    "    id: systemPanel\n"
    "    ColumnLayout {\n"
    "      spacing: 8\n\n"
    "      RowLayout {\n"
    "        Layout.fillWidth: true\n"
    "        PanelButton {\n"
    "          label: root.nativeMuted ? \"Audio · muted\" : \"Audio · \" + String(root.nativeVolume) + \"%\"\n"
    "          onPressed: root.openPanel = \"audio\"\n"
    "        }\n"
    "        PanelButton {\n"
    "          label: root.state.network && root.state.network.active\n"
    "                 ? \"Wi-Fi · \" + root.state.network.active\n"
    "                 : (root.state.network && root.state.network.enabled ? \"Wi-Fi · disconnected\" : \"Wi-Fi · off\")\n"
    "          onPressed: root.openPanel = \"network\"\n"
    "        }\n"
    "      }\n\n"
    "      RowLayout {\n"
    "        Layout.fillWidth: true\n"
    "        PanelButton {\n"
    "          label: root.state.bluetooth && root.state.bluetooth.powered ? \"Bluetooth · on\" : \"Bluetooth · off\"\n"
    "          onPressed: root.openPanel = \"bluetooth\"\n"
    "        }\n"
    "        PanelButton {\n"
    "          label: root.state.power && Number(root.state.power.battery) >= 0\n"
    "                 ? \"Power · \" + String(root.state.power.battery) + \"%\"\n"
    "                 : \"Power\"\n"
    "          onPressed: root.openPanel = \"power\"\n"
    "        }\n"
    "      }\n\n"
    "      RowLayout {\n"
    "        Layout.fillWidth: true\n"
    "        PanelButton { label: \"AI limits\"; onPressed: root.openPanel = \"agents\" }\n"
    "        PanelButton {\n"
    "          label: \"Updates · \" + String(root.state.updates ? root.state.updates.count : 0)\n"
    "          onPressed: root.openPanel = \"updates\"\n"
    "        }\n"
    "      }\n\n"
    "      RowLayout {\n"
    "        Layout.fillWidth: true\n"
    "        PanelButton {\n"
    "          label: (root.state.notifications && root.state.notifications.dnd ? \"DND · \" : \"Notifications · \") + String(historyModel.count)\n"
    "          onPressed: root.openPanel = \"notifications\"\n"
    "        }\n"
    "        PanelButton {\n"
    "          label: \"Calendar · \" + Qt.formatDateTime(root.clockNow, \"d MMM\")\n"
    "          onPressed: root.openCalendar()\n"
    "        }\n"
    "      }\n"
    "    }\n"
    "  }\n\n"
    "  Component {\n"
    "    id: audioPanel\n",
    "system panel component",
)

SHELL.write_text(text)
shutil.copy2(APPLICATIONS_COMPONENT, RUNTIME / APPLICATIONS_COMPONENT.name)
shutil.copy2(BOOKMARKS_COMPONENT, RUNTIME / BOOKMARKS_COMPONENT.name)
