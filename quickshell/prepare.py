#!/usr/bin/env python3
"""Build the runtime Quickshell config with event-driven Hyprland bar state."""

from pathlib import Path
import os

HOME = Path.home()
ROOT = HOME / "github/dotfiles/quickshell"
SOURCE = ROOT / "shell.qml"
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache"))
OUT_DIR = CACHE_HOME / "dots-shell/quickshell"
OUT = OUT_DIR / "shell.qml"

text = SOURCE.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise RuntimeError(f"prepare.py: missing expected {label} block")
    text = text.replace(old, new, 1)


replace_once(
    "import Quickshell.Wayland\n",
    "import Quickshell.Wayland\nimport Quickshell.Hyprland\n",
    "Hyprland import",
)

replace_once(
    "          Repeater {\n"
    "            model: root.occupiedWorkspaces\n"
    "            ClickButton {\n"
    "              required property var modelData\n"
    "              label: String(modelData)\n"
    "              active: Number(root.state.workspace || 1) === Number(modelData)\n"
    "              onPressed: root.backendAction(\"workspace\", \"focus\", modelData)\n"
    "            }\n"
    "          }\n",
    "          Repeater {\n"
    "            model: Hyprland.workspaces\n"
    "            ClickButton {\n"
    "              required property var modelData\n"
    "              visible: modelData.id > 0 && modelData.toplevels.values.length > 0\n"
    "              label: String(modelData.id)\n"
    "              active: modelData.focused\n"
    "              onPressed: modelData.activate()\n"
    "            }\n"
    "          }\n",
    "workspace repeater",
)

replace_once(
    "    function showOsd(icon: string, label: string, value: string): string {\n"
    "      root.showOsd(icon, label, Number(value), true)\n"
    "      return \"ok\"\n"
    "    }\n",
    "    function showOsd(icon: string, label: string, value: string): string {\n"
    "      root.showOsd(icon, label, Number(value), true)\n"
    "      return \"ok\"\n"
    "    }\n"
    "    function layoutChanged(label: string): string {\n"
    "      var merged = root.state\n"
    "      merged.layout = label\n"
    "      root.state = Object.assign({}, merged)\n"
    "      root.showOsd(\"LANG\", label, 0, false)\n"
    "      return \"ok\"\n"
    "    }\n",
    "IPC showOsd",
)

replace_once(
    "      implicitHeight: 30\n",
    "      implicitHeight: 34\n",
    "top bar height",
)

replace_once(
    "    implicitHeight: 28\n"
    "    implicitWidth: Math.max(28, textItem.implicitWidth + 14)\n",
    "    implicitHeight: 32\n"
    "    implicitWidth: Math.max(32, textItem.implicitWidth + 16)\n",
    "ClickButton size",
)

replace_once(
    "      color: \"#ebdbb2\"\n"
    "      font.family: \"monospace\"\n"
    "      font.pixelSize: 12\n",
    "      color: \"#fbf1c7\"\n"
    "      font.family: \"monospace\"\n"
    "      font.bold: true\n"
    "      font.pixelSize: 14\n",
    "ClickButton font",
)

replace_once(
    "          color: \"#d5c4a1\"\n"
    "          font.family: \"monospace\"\n"
    "          font.pixelSize: 12\n"
    "          elide: Text.ElideRight\n",
    "          color: \"#ebdbb2\"\n"
    "          font.family: \"monospace\"\n"
    "          font.pixelSize: 13\n"
    "          elide: Text.ElideRight\n",
    "active window title font",
)

OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT.write_text(text)
print(OUT_DIR)
