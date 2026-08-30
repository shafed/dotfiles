#!/usr/bin/env python3
"""Build the runtime Quickshell config from the tracked base shell."""

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


# Native Quickshell services own realtime desktop state.
replace_once(
    "import Quickshell.Wayland\n",
    "import Quickshell.Wayland\n"
    "import Quickshell.Hyprland\n"
    "import Quickshell.Services.Pipewire\n",
    "native service imports",
)

# The old Python workspace helper is no longer part of the runtime shell.
replace_once(
    '  readonly property string workspacesBackend: home + "/github/dotfiles/quickshell/workspaces.py"\n',
    "",
    "workspace backend property",
)
replace_once(
    "  property var occupiedWorkspaces: []\n",
    "",
    "occupied workspace state",
)

# Calendar, native audio state, and lightweight in-shell brightness sampling.
replace_once(
    "  property bool osdOpen: false\n",
    "  property bool osdOpen: false\n"
    "  property date clockNow: new Date()\n"
    "  property date calendarMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)\n"
    "  readonly property var audioSink: Pipewire.defaultAudioSink\n"
    "  readonly property int nativeVolume: audioSink && audioSink.ready && audioSink.audio\n"
    "                                      ? Math.round(audioSink.audio.volume * 100)\n"
    "                                      : Number(state.audio ? state.audio.volume : 0)\n"
    "  readonly property bool nativeMuted: audioSink && audioSink.ready && audioSink.audio\n"
    "                                      ? audioSink.audio.muted\n"
    "                                      : !!(state.audio && state.audio.muted)\n"
    "  property bool nativeAudioInitialized: false\n"
    "  property int lastNativeVolume: -1\n"
    "  property bool lastNativeMuted: false\n"
    "  property string backlightPath: \"\"\n"
    "  property int backlightMax: 0\n",
    "native shell state",
)

replace_once(
    "  function backendAction(domain, action, arg) {\n"
    "    var argv = [\"python3\", backend, \"action\", domain, action]\n"
    "    if (arg !== undefined && arg !== null && String(arg) !== \"\") argv.push(String(arg))\n"
    "    run(argv)\n"
    "    fastRefreshDelay.restart()\n"
    "    fullRefreshDelay.restart()\n"
    "    if (domain === \"workspace\") workspaceRefreshDelay.restart()\n"
    "  }\n",
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
    "  function syncNativeAudio() {\n"
    "    if (!audioSink || !audioSink.ready || !audioSink.audio) return\n"
    "    var volume = Math.max(0, Math.min(150, nativeVolume))\n"
    "    var muted = nativeMuted\n"
    "    if (!nativeAudioInitialized) {\n"
    "      lastNativeVolume = volume\n"
    "      lastNativeMuted = muted\n"
    "      nativeAudioInitialized = true\n"
    "      return\n"
    "    }\n"
    "    if (volume !== lastNativeVolume || muted !== lastNativeMuted)\n"
    "      showOsd(muted ? \"MUTE\" : \"VOL\", String(volume) + \"%\", volume, true)\n"
    "    lastNativeVolume = volume\n"
    "    lastNativeMuted = muted\n"
    "  }\n\n"
    "  function adjustNativeVolume(delta) {\n"
    "    if (!audioSink || !audioSink.ready || !audioSink.audio) return\n"
    "    audioSink.audio.volume = Math.max(0, Math.min(1.5, audioSink.audio.volume + delta))\n"
    "  }\n\n"
    "  function toggleNativeMute() {\n"
    "    if (!audioSink || !audioSink.ready || !audioSink.audio) return\n"
    "    audioSink.audio.muted = !audioSink.audio.muted\n"
    "  }\n\n"
    "  function applyLayoutEvent(event) {\n"
    "    if (!event || String(event.name || \"\") !== \"activelayout\") return\n"
    "    var parts = null\n"
    "    try { if (event.parse) parts = event.parse(2) } catch (e) {}\n"
    "    if (!parts || parts.length < 2) {\n"
    "      var raw = String(event.data || \"\")\n"
    "      var comma = raw.indexOf(\",\")\n"
    "      if (comma >= 0) parts = [raw.slice(0, comma), raw.slice(comma + 1)]\n"
    "    }\n"
    "    if (!parts || parts.length < 2) return\n"
    "    var keyboard = String(parts[0] || \"\")\n"
    "    if (keyboard.indexOf(\"hl-virtual-keyboard\") === 0) return\n"
    "    var layout = String(parts[1] || \"\")\n"
    "    if (!layout) return\n"
    "    var merged = state\n"
    "    merged.layout = layout\n"
    "    state = Object.assign({}, merged)\n"
    "  }\n\n"
    "  function handleBrightness(value) {\n"
    "    var nextValue = Number(value)\n"
    "    if (isNaN(nextValue) || backlightMax <= 0) return\n"
    "    var percent = Math.max(0, Math.min(100, Math.round(nextValue * 100 / backlightMax)))\n"
    "    if (lastBrightness < 0) {\n"
    "      lastBrightness = percent\n"
    "      return\n"
    "    }\n"
    "    if (percent !== lastBrightness) {\n"
    "      lastBrightness = percent\n"
    "      showOsd(\"SUN\", String(percent) + \"%\", percent, true)\n"
    "    }\n"
    "  }\n\n"
    "  function backendAction(domain, action, arg) {\n"
    "    var argv = [\"python3\", backend, \"action\", domain, action]\n"
    "    if (arg !== undefined && arg !== null && String(arg) !== \"\") argv.push(String(arg))\n"
    "    run(argv)\n"
    "    fullRefreshDelay.restart()\n"
    "  }\n",
    "native helpers and backend action",
)

# Full snapshots initialize slow data, but must not overwrite the layout event
# that may have arrived more recently.
replace_once(
    "  function updateFull(next) {\n    state = next\n",
    "  function updateFull(next) {\n"
    "    if (state.layout) next.layout = state.layout\n"
    "    state = next\n",
    "full snapshot layout preservation",
)

# The old fast snapshot is no longer used for realtime UI. Remove its delayed
# OSD side effects so a manual invocation cannot produce stale duplicate OSDs.
replace_once(
    "\n    if (next.audio && lastVolume >= 0 && Number(next.audio.volume) !== lastVolume) {\n"
    "      showOsd(next.audio.muted ? \"MUTE\" : \"VOL\", Number(next.audio.volume) + \"%\", Number(next.audio.volume), true)\n"
    "    }\n"
    "    if (next.audio) lastVolume = Number(next.audio.volume)\n\n"
    "    if (laptop && next.brightness !== undefined && Number(next.brightness) >= 0 &&\n"
    "        lastBrightness >= 0 && Number(next.brightness) !== lastBrightness) {\n"
    "      showOsd(\"SUN\", Number(next.brightness) + \"%\", Number(next.brightness), true)\n"
    "    }\n"
    "    if (next.brightness !== undefined && Number(next.brightness) >= 0)\n"
    "      lastBrightness = Number(next.brightness)\n",
    "",
    "polling OSD logic",
)

# Startup only needs the slow snapshot; workspaces, layout, volume and brightness
# are owned by native Quickshell state.
replace_once(
    "  Component.onCompleted: {\n"
    "    run([\"pkill\", \"-x\", \"waybar\"])\n"
    "    fullProc.running = true\n"
    "    fastProc.running = true\n"
    "    workspaceProc.running = true\n"
    "  }\n",
    "  Component.onCompleted: {\n"
    "    run([\"pkill\", \"-x\", \"waybar\"])\n"
    "    fullProc.running = true\n"
    "  }\n",
    "startup polling",
)

# Delete the now-unused fast/workspace processes and timers from the generated QML.
replace_once(
    "  Process {\n"
    "    id: fastProc\n"
    "    command: [\"python3\", root.backend, \"fast\"]\n"
    "    stdout: StdioCollector {\n"
    "      waitForEnd: true\n"
    "      onStreamFinished: {\n"
    "        try { root.updateFast(JSON.parse(text)) } catch (e) { console.warn(\"dots-shell fast snapshot:\", e) }\n"
    "      }\n"
    "    }\n"
    "  }\n\n",
    "",
    "fast process",
)
replace_once(
    "  Process {\n"
    "    id: workspaceProc\n"
    "    command: [\"python3\", root.workspacesBackend]\n"
    "    stdout: StdioCollector {\n"
    "      waitForEnd: true\n"
    "      onStreamFinished: {\n"
    "        try { root.occupiedWorkspaces = JSON.parse(text) } catch (e) { root.occupiedWorkspaces = [] }\n"
    "      }\n"
    "    }\n"
    "  }\n\n",
    "",
    "workspace process",
)
replace_once(
    "  Timer {\n"
    "    interval: 800\n"
    "    repeat: true\n"
    "    running: true\n"
    "    onTriggered: {\n"
    "      if (!fastProc.running) fastProc.running = true\n"
    "      if (!workspaceProc.running) workspaceProc.running = true\n"
    "    }\n"
    "  }\n\n",
    "",
    "800ms polling timer",
)
replace_once(
    "  Timer {\n"
    "    id: fastRefreshDelay\n"
    "    interval: 250\n"
    "    onTriggered: if (!fastProc.running) fastProc.running = true\n"
    "  }\n\n",
    "",
    "fast refresh timer",
)
replace_once(
    "  Timer {\n"
    "    id: workspaceRefreshDelay\n"
    "    interval: 180\n"
    "    onTriggered: if (!workspaceProc.running) workspaceProc.running = true\n"
    "  }\n\n",
    "",
    "workspace refresh timer",
)

# Bind the default PipeWire sink so its volume/mute properties are valid.
replace_once(
    "  ListModel { id: historyModel }\n",
    "  PwObjectTracker { objects: [root.audioSink] }\n\n"
    "  Connections {\n"
    "    target: Hyprland\n"
    "    function onRawEvent(event) { root.applyLayoutEvent(event) }\n"
    "  }\n\n"
    "  Process {\n"
    "    id: backlightDiscoverProc\n"
    "    running: true\n"
    "    command: [\"bash\", \"-lc\", \"for d in /sys/class/backlight/*; do [ -r \\\"$d/brightness\\\" ] && [ -r \\\"$d/max_brightness\\\" ] && { printf '%s\\\\n' \\\"$d\\\"; break; }; done\"]\n"
    "    stdout: StdioCollector {\n"
    "      waitForEnd: true\n"
    "      onStreamFinished: root.backlightPath = text.trim()\n"
    "    }\n"
    "  }\n\n"
    "  FileView {\n"
    "    id: backlightMaxFile\n"
    "    path: root.backlightPath ? root.backlightPath + \"/max_brightness\" : \"\"\n"
    "    onTextChanged: {\n"
    "      var value = Number(text().trim())\n"
    "      if (!isNaN(value) && value > 0) root.backlightMax = value\n"
    "    }\n"
    "  }\n\n"
    "  FileView {\n"
    "    id: backlightValueFile\n"
    "    path: root.backlightPath ? root.backlightPath + \"/brightness\" : \"\"\n"
    "    onTextChanged: root.handleBrightness(text().trim())\n"
    "  }\n\n"
    "  Timer {\n"
    "    interval: 150\n"
    "    repeat: true\n"
    "    running: root.backlightPath !== \"\"\n"
    "    onTriggered: backlightValueFile.reload()\n"
    "  }\n\n"
    "  ListModel { id: historyModel }\n",
    "native trackers",
)

# Volume properties become live once the sink is bound.
replace_once(
    "  NotificationServer {\n",
    "  onNativeVolumeChanged: syncNativeAudio()\n"
    "  onNativeMutedChanged: syncNativeAudio()\n"
    "  onAudioSinkChanged: {\n"
    "    nativeAudioInitialized = false\n"
    "    Qt.callLater(syncNativeAudio)\n"
    "  }\n\n"
    "  NotificationServer {\n",
    "native audio handlers",
)

# IPC remains for deliberate shell actions only.
replace_once(
    "    function refresh(): string {\n"
    "      if (!root.fullProc.running) root.fullProc.running = true\n"
    "      if (!root.fastProc.running) root.fastProc.running = true\n"
    "      if (!root.workspaceProc.running) root.workspaceProc.running = true\n"
    "      return \"ok\"\n"
    "    }\n",
    "    function refresh(): string {\n"
    "      if (!root.fullProc.running) root.fullProc.running = true\n"
    "      return \"ok\"\n"
    "    }\n",
    "IPC refresh",
)

# Workspaces use the native reactive Hyprland model.
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

# Keyboard layout first; warning-aware AI indicator follows updates.
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

# Master audio is entirely native: no Python round trip for bar state or controls.
replace_once(
    "          ClickButton {\n"
    "            label: root.state.audio && root.state.audio.muted\n"
    "                   ? \"MUTE\"\n"
    "                   : \"VOL \" + String(root.state.audio ? root.state.audio.volume : 0) + \"%\"\n"
    "            active: root.openPanel === \"audio\"\n",
    "          ClickButton {\n"
    "            label: root.nativeMuted ? \"MUTE\" : \"VOL \" + String(root.nativeVolume) + \"%\"\n"
    "            active: root.openPanel === \"audio\"\n",
    "top bar audio",
)
replace_once(
    "          PanelButton {\n"
    "            Layout.fillWidth: true\n"
    "            label: root.state.audio && root.state.audio.muted ? \"Unmute\" : \"Mute\"\n"
    "            onPressed: root.backendAction(\"audio\", \"mute\", \"\")\n"
    "          }\n"
    "          PanelButton {\n"
    "            Layout.preferredWidth: 74\n"
    "            label: \"-5%\"\n"
    "            onPressed: root.backendAction(\"audio\", \"delta\", \"-5\")\n"
    "          }\n"
    "          PanelButton {\n"
    "            Layout.preferredWidth: 74\n"
    "            label: \"+5%\"\n"
    "            onPressed: root.backendAction(\"audio\", \"delta\", \"5\")\n"
    "          }\n",
    "          PanelButton {\n"
    "            Layout.fillWidth: true\n"
    "            label: root.nativeMuted ? \"Unmute\" : \"Mute\"\n"
    "            onPressed: root.toggleNativeMute()\n"
    "          }\n"
    "          PanelButton {\n"
    "            Layout.preferredWidth: 74\n"
    "            label: \"-5%\"\n"
    "            onPressed: root.adjustNativeVolume(-0.05)\n"
    "          }\n"
    "          PanelButton {\n"
    "            Layout.preferredWidth: 74\n"
    "            label: \"+5%\"\n"
    "            onPressed: root.adjustNativeVolume(0.05)\n"
    "          }\n",
    "native audio controls",
)

# Move the clock directly before the system tray and make it a calendar button.
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
replace_once(
    "                           root.openPanel === \"power\" ? powerPanel :\n"
    "                           root.openPanel === \"agents\" ? agentsPanel :\n",
    "                           root.openPanel === \"power\" ? powerPanel :\n"
    "                           root.openPanel === \"calendar\" ? calendarPanel :\n"
    "                           root.openPanel === \"agents\" ? agentsPanel :\n",
    "calendar loader",
)
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

# Compact 30px geometry remains from shell.qml. Top-bar typography is Inter 14.
replace_once(
    "    property bool active: false\n"
    "    signal pressed()\n",
    "    property bool active: false\n"
    "    property string textColor: \"#fbf1c7\"\n"
    "    signal pressed()\n",
    "ClickButton text color property",
)
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
