#!/usr/bin/env python3
"""Apply picker ranking and standard popover dismissal to generated Quickshell."""

from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: prepare-ui-fixes.py <runtime-dir>")

runtime = Path(sys.argv[1]).resolve()
shell_path = runtime / "shell.qml"
launcher_path = runtime / "DesktopLauncher.qml"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"prepare-ui-fixes.py: missing expected {label} block")
    return text.replace(old, new, 1)


shell = shell_path.read_text()

# Keep the AI label itself neutral; per-limit percentages/bars carry warning color.
shell = shell.replace('            textColor: root.aiLimitColor()\n', '', 1)

# A single fullscreen layer-shell surface gives reliable Escape/outside-click
# dismissal. The visible card stays top-right and consumes clicks inside it.
shell = replace_once(
    shell,
    '''  PanelWindow {
    id: panelWindow
    visible: root.openPanel !== ""
    anchors { top: true; right: true }
    margins.top: 34
    margins.right: 6
    implicitWidth: 430
    implicitHeight: 560
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
      anchors.fill: parent
      color: "#1d2021"
      border.color: "#504945"
      border.width: 1
      radius: 8
''',
    '''  PanelWindow {
    id: panelWindow
    visible: root.openPanel !== ""
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: {
      if (visible) Qt.callLater(function() { panelCard.forceActiveFocus() })
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.openPanel = ""
    }

    Rectangle {
      id: panelCard
      width: Math.min(430, parent.width - 12)
      height: Math.min(560, parent.height - 46)
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 34
      anchors.rightMargin: 6
      focus: root.openPanel !== ""
      Keys.onEscapePressed: root.openPanel = ""
      color: "#1d2021"
      border.color: "#504945"
      border.width: 1
      radius: 8

      MouseArea {
        anchors.fill: parent
      }
''',
    "system popover surface",
)
shell_path.write_text(shell)

# Applications keeps its existing matcher as the relevance gate; usage only
# adds a bounded logarithmic bonus among already-plausible matches.
launcher = launcher_path.read_text()
launcher = replace_once(
    launcher,
    '''  function usageCount(entry) {
    return Number(usage[usageKey(entry)] || 0)
  }

  function recordUse(entry) {
''',
    '''  function usageCount(entry) {
    return Number(usage[usageKey(entry)] || 0)
  }

  function usageBonus(entry) {
    var count = usageCount(entry)
    if (count <= 0) return 0
    return Math.min(3600, Math.log(count + 1) / Math.LN2 * 1200)
  }

  function recordUse(entry) {
''',
    "application usage bonus",
)
launcher = replace_once(
    launcher,
    '''      result.push({
        entry: entry,
        rank: rank,
        used: used,
        name: String(entry.name || entry.id).toLowerCase()
      })
''',
    '''      result.push({
        entry: entry,
        rank: rank,
        weightedRank: rank + usageBonus(entry),
        used: used,
        name: String(entry.name || entry.id).toLowerCase()
      })
''',
    "application weighted rank",
)
launcher = replace_once(
    launcher,
    '''    result.sort(function(a, b) {
      if (q && a.rank !== b.rank) return b.rank - a.rank
      if (!q && a.used !== b.used) return b.used - a.used
''',
    '''    result.sort(function(a, b) {
      if (q && a.weightedRank !== b.weightedRank) return b.weightedRank - a.weightedRank
      if (!q && a.used !== b.used) return b.used - a.used
''',
    "application weighted sort",
)
launcher_path.write_text(launcher)
