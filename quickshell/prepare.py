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

# Layout changes are pushed by layout-watch.py. Do not let an older in-flight
# fast snapshot overwrite a freshly received keyboard-layout event.
replace_once(
    "    if (next.layout !== undefined) merged.layout = next.layout\n",
    "",
    "fast layout assignment",
)

# Keep the event-driven layout value when the slower full snapshot refreshes
# unrelated state. The first full snapshot still initializes it at startup.
replace_once(
    "  function updateFull(next) {\n    state = next\n",
    "  function updateFull(next) {\n"
    "    if (state.layout) next.layout = state.layout\n"
    "    state = next\n",
    "full snapshot layout preservation",
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
    "      return \"ok\"\n"
    "    }\n",
    "IPC showOsd",
)

# Keyboard layout is the first item in the right-side status block.
replace_once(
    "          ClickButton {\n"
    "            visible: Number(root.state.updates ? root.state.updates.count : 0) > 0\n"
    "            label: \"↑\" + String(root.state.updates ? root.state.updates.count : 0)\n"
    "            onPressed: root.togglePanel(\"updates\")\n"
    "          }\n\n"
    "          ClickButton {\n"
    "            visible: root.state.agents && root.state.agents.length > 0\n"
    "            label: \"AI\"\n"
    "            active: root.openPanel === \"agents\"\n"
    "            onPressed: root.togglePanel(\"agents\")\n"
    "          }\n\n"
    "          ClickButton {\n"
    "            label: root.layoutLabel(root.state.layout)\n"
    "          }\n",
    "          ClickButton {\n"
    "            label: root.layoutLabel(root.state.layout)\n"
    "          }\n\n"
    "          ClickButton {\n"
    "            visible: Number(root.state.updates ? root.state.updates.count : 0) > 0\n"
    "            label: \"↑\" + String(root.state.updates ? root.state.updates.count : 0)\n"
    "            onPressed: root.togglePanel(\"updates\")\n"
    "          }\n\n"
    "          ClickButton {\n"
    "            visible: root.state.agents && root.state.agents.length > 0\n"
    "            label: \"AI\"\n"
    "            active: root.openPanel === \"agents\"\n"
    "            onPressed: root.togglePanel(\"agents\")\n"
    "          }\n",
    "right-side status order",
)

# Match the old compact 30 px bar geometry.
# shell.qml already uses a 30 px bar and 28 px buttons, so no geometry rewrite
# is needed here.

# Use Inter for the top bar while keeping the old Waybar-like 13 px normal weight.
replace_once(
    "      color: \"#ebdbb2\"\n"
    "      font.family: \"monospace\"\n"
    "      font.pixelSize: 12\n",
    "      color: \"#fbf1c7\"\n"
    "      font.family: \"Inter\"\n"
    "      font.pixelSize: 13\n",
    "ClickButton font",
)

replace_once(
    "          color: \"#d5c4a1\"\n"
    "          font.family: \"monospace\"\n"
    "          font.pixelSize: 12\n"
    "          elide: Text.ElideRight\n",
    "          color: \"#fbf1c7\"\n"
    "          font.family: \"Inter\"\n"
    "          font.pixelSize: 13\n"
    "          elide: Text.ElideRight\n",
    "active window title font",
)

OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT.write_text(text)
print(OUT_DIR)
