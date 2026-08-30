#!/usr/bin/env python3
"""Build the effective Quickshell config from the tracked shell template.

This keeps the large shell.qml readable while applying host-sensitive bar
behaviour at launch: laptop-only controls, compact keyboard layout labels,
and occupied Hyprland workspaces with mouse activation.
"""
from pathlib import Path
import os
import re
import sys

repo = Path(os.environ.get("DOTFILES", Path.home() / "github/dotfiles"))
src = repo / "quickshell/shell.qml"
out_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "dots-shell/quickshell"
out = out_dir / "shell.qml"

text = src.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise RuntimeError(f"prepare.py: expected {label} block was not found")
    text = text.replace(old, new, 1)


replace_once(
    "import Quickshell.Wayland\n",
    "import Quickshell.Wayland\nimport Quickshell.Hyprland\n",
    "Hyprland import anchor",
)

replace_once(
    "  })\n  property string openPanel: \"\"\n",
    "  })\n\n  readonly property bool isLaptop: state.power && Number(state.power.battery) >= 0\n\n  property string openPanel: \"\"\n",
    "state properties",
)

replace_once(
    "  function togglePanel(name) {\n    openPanel = openPanel === name ? \"\" : name\n    if (openPanel !== \"\" && !fullProc.running) fullProc.running = true\n  }\n",
    "  function normalizeLayout(value) {\n"
    "    var raw = String(value || \"\")\n"
    "    var lower = raw.toLowerCase()\n"
    "    if (lower.indexOf(\"russian\") >= 0 || lower === \"ru\" || lower.indexOf(\"рус\") >= 0) return \"RU\"\n"
    "    if (lower.indexOf(\"english\") >= 0 || lower.indexOf(\"us\") >= 0 || lower === \"en\") return \"EN\"\n"
    "    if (!raw) return \"--\"\n"
    "    return raw.substring(0, 2).toUpperCase()\n"
    "  }\n\n"
    "  function togglePanel(name) {\n"
    "    if (!isLaptop && (name === \"network\" || name === \"bluetooth\")) return\n"
    "    openPanel = openPanel === name ? \"\" : name\n"
    "    if (openPanel !== \"\" && !fullProc.running) fullProc.running = true\n"
    "  }\n",
    "togglePanel",
)

replace_once(
    "    if (next.brightness !== undefined && Number(next.brightness) >= 0 &&\n        lastBrightness >= 0 && Number(next.brightness) !== lastBrightness) {\n",
    "    if (isLaptop && next.brightness !== undefined && Number(next.brightness) >= 0 &&\n        lastBrightness >= 0 && Number(next.brightness) !== lastBrightness) {\n",
    "brightness OSD condition",
)

workspace_pattern = re.compile(
    r"          Repeater \{\n"
    r"            model: 10\n"
    r"            ClickButton \{\n"
    r"              required property int index\n"
    r"              label: String\(index \+ 1\)\n"
    r"              active: Number\(root\.state\.workspace \|\| 1\) === index \+ 1\n"
    r"              onPressed: root\.backendAction\(\"workspace\", \"focus\", index \+ 1\)\n"
    r"            \}\n"
    r"          \}\n"
)
workspace_replacement = """          Repeater {
            model: Hyprland.workspaces
            ClickButton {
              required property var modelData
              visible: modelData.id > 0 && modelData.toplevels.values.length > 0
              label: String(modelData.id)
              active: modelData.focused
              onPressed: modelData.activate()
            }
          }
"""
text, count = workspace_pattern.subn(workspace_replacement, text, count=1)
if count != 1:
    raise RuntimeError("prepare.py: expected workspace block was not found")

replace_once(
    '            label: root.state.layout ? String(root.state.layout).replace("English (US)", "US").replace("Russian", "RU") : "--"\n',
    '            label: root.normalizeLayout(root.state.layout)\n',
    "layout indicator",
)

replace_once(
    '          ClickButton {\n            label: "BT"\n',
    '          ClickButton {\n            visible: root.isLaptop\n            label: "BT"\n',
    "Bluetooth button",
)

replace_once(
    '          ClickButton {\n            label: root.state.network && root.state.network.active ? "NET" : "NET!"\n',
    '          ClickButton {\n            visible: root.isLaptop\n            label: root.state.network && root.state.network.active ? "NET" : "NET!"\n',
    "network button",
)

replace_once(
    '            visible: root.state.power && Number(root.state.power.battery) >= 0\n',
    '            visible: root.isLaptop\n',
    "battery button",
)

out_dir.mkdir(parents=True, exist_ok=True)
out.write_text(text)
print(out)
