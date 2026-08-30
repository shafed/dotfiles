#!/usr/bin/env python3
"""Make the generated AI refresh control compact and timestamped."""

from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: prepare-agents-refresh-ui.py <runtime-dir>")

shell_path = Path(sys.argv[1]).resolve() / "shell.qml"
text = shell_path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise RuntimeError(f"prepare-agents-refresh-ui.py: missing expected {label} block")
    text = text.replace(old, new, 1)


replace_once(
    '''  property bool agentsLiveRefreshed: false

  function agentTitle(agent) {
''',
    '''  property bool agentsLiveRefreshed: false
  property double agentsLastUpdatedMs: 0

  function formatAgentsLastUpdated() {
    if (agentsLastUpdatedMs <= 0)
      return agentsRefreshProc.running ? "updating..." : "never"
    var nowMs = clockNow ? clockNow.getTime() : Date.now()
    var seconds = Math.max(0, Math.floor((nowMs - agentsLastUpdatedMs) / 1000))
    if (seconds < 60) return "just now"
    var minutes = Math.floor(seconds / 60)
    if (minutes < 60) return minutes + "m ago"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h ago"
    return Math.floor(hours / 24) + "d ago"
  }

  function agentTitle(agent) {
''',
    "AI refresh timestamp helpers",
)

replace_once(
    '''          root.agentsLiveRefreshed = true
''',
    '''          root.agentsLiveRefreshed = true
          root.agentsLastUpdatedMs = Date.now()
''',
    "AI refresh completion timestamp",
)

replace_once(
    '''        PanelButton {
          label: agentsRefreshProc.running ? "Refreshing..." : "Refresh"
          onPressed: if (!agentsRefreshProc.running) agentsRefreshProc.running = true
        }
''',
    '''        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Text {
            Layout.fillWidth: true
            text: "Last updated: " + root.formatAgentsLastUpdated()
            color: "#a89984"
            font.family: "monospace"
            font.pixelSize: 11
            verticalAlignment: Text.AlignVCenter
          }

          Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 4
            color: refreshMouse.containsMouse ? "#504945" : "transparent"
            opacity: agentsRefreshProc.running ? 0.55 : 1.0

            Text {
              anchors.centerIn: parent
              text: "↻"
              color: "#d5c4a1"
              font.family: "Inter"
              font.pixelSize: 17
            }

            MouseArea {
              id: refreshMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: !agentsRefreshProc.running
              cursorShape: Qt.PointingHandCursor
              onClicked: agentsRefreshProc.running = true
            }
          }
        }
''',
    "compact AI refresh row",
)

shell_path.write_text(text)
