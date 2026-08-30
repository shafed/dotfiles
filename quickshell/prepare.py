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

# Calendar and reactive clock state.
replace_once(
    "  property bool osdOpen: false\n",
    "  property bool osdOpen: false\n"
    "  property date clockNow: new Date()\n"
    "  property date calendarMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)\n",
    "calendar state",
)

replace_once(
    "  function backendAction(domain, action, arg) {\n",
    "  function calendarCellDate(index) {\n"
    "    var first = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1)\n"
    "    var mondayOffset = (first.getDay() + 6) % 7\n"
    "    return new Date(first.getFullYear(), first.getMonth(), index - mondayOffset + 1)\n"
    "  }\n\n"
    "  function sameCalendarDay(a, b) {\n"
    "    return a.getFullYear() === b.getFullYear() &&\n"
    "           a.getMonth() === b.getMonth() &&\n"
    "           a.getDate() === b.getDate()\n"
    "  }\n\n"
    "  function shiftCalendarMonth(delta) {\n"
    "    calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + delta, 1)\n"
    "  }\n\n"
    "  function openCalendar() {\n"
    "    if (openPanel !== \"calendar\") {\n"
    "      var now = new Date()\n"
    "      calendarMonth = new Date(now.getFullYear(), now.getMonth(), 1)\n"
    "    }\n"
    "    togglePanel(\"calendar\")\n"
    "  }\n\n"
    "  function aiLimitColor() {\n"
    "    var rows = state.agents || []\n"
    "    var lowestRemaining = 1.0\n"
    "    var found = false\n"
    "    for (var i = 0; i < rows.length; i++) {\n"
    "      var limits = rows[i].limits || []\n"
    "      for (var j = 0; j < limits.length; j++) {\n"
    "        var used = Number(limits[j].percent)\n"
    "        if (isNaN(used)) continue\n"
    "        found = true\n"
    "        used = Math.max(0, Math.min(1, used))\n"
    "        lowestRemaining = Math.min(lowestRemaining, 1 - used)\n"
    "      }\n"
    "    }\n"
    "    if (!found) return \"#fbf1c7\"\n"
    "    if (lowestRemaining <= 0.10) return \"#ea6962\"\n"
    "    if (lowestRemaining <= 0.30) return \"#d8a657\"\n"
    "    return \"#fbf1c7\"\n"
    "  }\n\n"
    "  function backendAction(domain, action, arg) {\n",
    "calendar and AI helpers",
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
    "            textColor: root.aiLimitColor()\n"
    "            active: root.openPanel === \"agents\"\n"
    "            onPressed: root.togglePanel(\"agents\")\n"
    "          }\n",
    "right-side status order",
)

# Move the clock directly before the system tray and open a calendar from it.
replace_once(
    "          ClickButton {\n"
    "            label: Qt.formatDateTime(new Date(), \"ddd HH:mm\")\n"
    "            onPressed: root.togglePanel(\"power\")\n"
    "          }\n",
    "",
    "old clock position",
)

replace_once(
    "          Repeater {\n"
    "            model: SystemTray.items\n",
    "          ClickButton {\n"
    "            label: Qt.formatDateTime(root.clockNow, \"ddd HH:mm\")\n"
    "            active: root.openPanel === \"calendar\"\n"
    "            onPressed: root.openCalendar()\n"
    "          }\n\n"
    "          Repeater {\n"
    "            model: SystemTray.items\n",
    "clock before tray",
)

# Keep the clock current without using the backend snapshot loop.
replace_once(
    "  Timer {\n"
    "    id: osdTimer\n",
    "  Timer {\n"
    "    interval: 30000\n"
    "    repeat: true\n"
    "    running: true\n"
    "    onTriggered: root.clockNow = new Date()\n"
    "  }\n\n"
    "  Timer {\n"
    "    id: osdTimer\n",
    "clock timer",
)

# Route the generic popup to the calendar component.
replace_once(
    "                           root.openPanel === \"power\" ? powerPanel :\n"
    "                           root.openPanel === \"agents\" ? agentsPanel :\n",
    "                           root.openPanel === \"power\" ? powerPanel :\n"
    "                           root.openPanel === \"calendar\" ? calendarPanel :\n"
    "                           root.openPanel === \"agents\" ? agentsPanel :\n",
    "calendar loader",
)

# Native month view: Monday-first, six-week grid, today highlighted.
replace_once(
    "  Component {\n"
    "    id: powerPanel\n",
    "  Component {\n"
    "    id: calendarPanel\n"
    "    ColumnLayout {\n"
    "      spacing: 10\n\n"
    "      RowLayout {\n"
    "        Layout.fillWidth: true\n"
    "        ClickButton { label: \"‹\"; onPressed: root.shiftCalendarMonth(-1) }\n"
    "        Text {\n"
    "          Layout.fillWidth: true\n"
    "          text: Qt.formatDateTime(root.calendarMonth, \"MMMM yyyy\")\n"
    "          color: \"#fbf1c7\"\n"
    "          font.family: \"Inter\"\n"
    "          font.bold: true\n"
    "          font.pixelSize: 16\n"
    "          horizontalAlignment: Text.AlignHCenter\n"
    "        }\n"
    "        ClickButton { label: \"›\"; onPressed: root.shiftCalendarMonth(1) }\n"
    "      }\n\n"
    "      GridLayout {\n"
    "        Layout.fillWidth: true\n"
    "        columns: 7\n"
    "        columnSpacing: 4\n"
    "        rowSpacing: 4\n\n"
    "        Repeater {\n"
    "          model: [\"Mon\", \"Tue\", \"Wed\", \"Thu\", \"Fri\", \"Sat\", \"Sun\"]\n"
    "          Text {\n"
    "            Layout.fillWidth: true\n"
    "            Layout.preferredHeight: 24\n"
    "            text: modelData\n"
    "            color: \"#a89984\"\n"
    "            font.family: \"Inter\"\n"
    "            font.pixelSize: 12\n"
    "            horizontalAlignment: Text.AlignHCenter\n"
    "            verticalAlignment: Text.AlignVCenter\n"
    "          }\n"
    "        }\n\n"
    "        Repeater {\n"
    "          model: 42\n"
    "          Rectangle {\n"
    "            required property int index\n"
    "            property date cellDate: root.calendarCellDate(index)\n"
    "            property bool inMonth: cellDate.getMonth() === root.calendarMonth.getMonth()\n"
    "            property bool today: root.sameCalendarDay(cellDate, root.clockNow)\n"
    "            Layout.fillWidth: true\n"
    "            Layout.preferredHeight: 40\n"
    "            radius: 5\n"
    "            color: today ? \"#d8a657\" : \"transparent\"\n"
    "            border.width: inMonth && !today ? 1 : 0\n"
    "            border.color: \"#3c3836\"\n"
    "            Text {\n"
    "              anchors.centerIn: parent\n"
    "              text: parent.cellDate.getDate()\n"
    "              color: parent.today ? \"#1d2021\" : (parent.inMonth ? \"#fbf1c7\" : \"#665c54\")\n"
    "              font.family: \"Inter\"\n"
    "              font.pixelSize: 14\n"
    "              font.bold: parent.today\n"
    "            }\n"
    "          }\n"
    "        }\n"
    "      }\n"
    "      Item { Layout.fillHeight: true }\n"
    "    }\n"
    "  }\n\n"
    "  Component {\n"
    "    id: powerPanel\n",
    "calendar component",
)

# Match the old compact 30 px bar geometry.
# shell.qml already uses a 30 px bar and 28 px buttons, so no geometry rewrite
# is needed here.

# Let individual top-bar buttons override their text color (AI uses this for
# low remaining rate-limit warnings).
replace_once(
    "    property bool active: false\n"
    "    signal pressed()\n",
    "    property bool active: false\n"
    "    property string textColor: \"#fbf1c7\"\n"
    "    signal pressed()\n",
    "ClickButton text color property",
)

# Use Inter for the top bar at 14 px normal weight.
replace_once(
    "      color: \"#ebdbb2\"\n"
    "      font.family: \"monospace\"\n"
    "      font.pixelSize: 12\n",
    "      color: button.textColor\n"
    "      font.family: \"Inter\"\n"
    "      font.pixelSize: 14\n",
    "ClickButton font",
)

replace_once(
    "          color: \"#d5c4a1\"\n"
    "          font.family: \"monospace\"\n"
    "          font.pixelSize: 12\n"
    "          elide: Text.ElideRight\n",
    "          color: \"#fbf1c7\"\n"
    "          font.family: \"Inter\"\n"
    "          font.pixelSize: 14\n"
    "          elide: Text.ElideRight\n",
    "active window title font",
)

OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT.write_text(text)
print(OUT_DIR)
