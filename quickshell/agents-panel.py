#!/usr/bin/env python3
"""Post-process generated Quickshell QML with a compact AI rate-limit panel."""

from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise RuntimeError(f"agents-panel.py: missing expected {label} block")
    text = text.replace(old, new, 1)


replace_once(
    "  function syncNativeAudio() {\n",
    '''  function agentTitle(agent) {
    var raw = String(agent && agent.name ? agent.name : "AI")
    var separator = raw.indexOf(" · ")
    if (separator >= 0) raw = raw.slice(0, separator)
    var plan = String(agent && agent.plan ? agent.plan : "")
    return raw + (plan ? " · " + plan : "")
  }

  function agentLimit(agent, weekly) {
    var limits = agent && agent.limits ? agent.limits : []
    for (var i = 0; i < limits.length; i++) {
      var limit = limits[i]
      var label = String(limit && limit.label ? limit.label : "").toLowerCase()
      if (weekly && label === "7d") return limit
      if (!weekly && label !== "7d") return limit
    }
    return null
  }

  function limitUsed(limit) {
    if (!limit) return 0
    var value = Number(limit.percent)
    if (isNaN(value)) return 0
    return Math.max(0, Math.min(1, value))
  }

  function limitColor(limit) {
    if (!limit) return "#a89984"
    var remaining = 1 - limitUsed(limit)
    if (remaining <= 0.10) return "#ea6962"
    if (remaining <= 0.30) return "#d8a657"
    return "#a9b665"
  }

  function formatLimitReset(raw) {
    if (raw === undefined || raw === null || String(raw) === "") return "Reset time unavailable"
    var numeric = Number(raw)
    var when = !isNaN(numeric) && numeric > 0
               ? new Date(numeric < 100000000000 ? numeric * 1000 : numeric)
               : new Date(String(raw))
    if (isNaN(when.getTime())) return "Reset time unavailable"

    var now = new Date()
    var delta = when.getTime() - now.getTime()
    if (delta > 0 && delta <= 24 * 60 * 60 * 1000) {
      var totalMinutes = Math.max(1, Math.ceil(delta / 60000))
      var hours = Math.floor(totalMinutes / 60)
      var minutes = totalMinutes % 60
      if (hours > 0) return "Resets in " + hours + "h " + minutes + "m"
      return "Resets in " + minutes + "m"
    }
    return "Resets " + Qt.formatDateTime(when, "MMM d, HH:mm")
  }

  function syncNativeAudio() {
''',
    "AI limit helpers",
)

replace_once(
    "  NotificationServer {\n",
    '''  Process {
    id: agentsRefreshProc
    command: ["python3", root.home + "/github/dotfiles/quickshell/agents-refresh.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var rows = JSON.parse(text)
          var merged = root.state
          merged.agents = rows
          root.state = Object.assign({}, merged)
        } catch (e) {
          console.warn("dots-shell agents refresh:", e)
        }
      }
    }
  }

  NotificationServer {
''',
    "AI refresh process",
)

old_panel = '''  Component {
    id: agentsPanel
    Flickable {
      contentWidth: width
      contentHeight: agentsColumn.implicitHeight
      clip: true
      ColumnLayout {
        id: agentsColumn
        width: parent.width
        spacing: 9

        Repeater {
          model: root.state.agents || []
          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: agentColumn.implicitHeight + 20
            radius: 6
            color: "#282828"
            border.color: "#504945"

            ColumnLayout {
              id: agentColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 10
              spacing: 5

              Heading { text: modelData.name }
              Text {
                text: "Today " + root.formatTokens(modelData.today) +
                      " · 7d " + root.formatTokens(modelData.week) +
                      " · " + modelData.sessions + " sessions"
                color: "#d5c4a1"
                font.family: "monospace"
                font.pixelSize: 12
              }
              Repeater {
                model: modelData.models || []
                Text {
                  required property var modelData
                  text: modelData.name + "  " + root.formatTokens(modelData.tokens)
                  color: "#a89984"
                  font.family: "monospace"
                  font.pixelSize: 11
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }
        }
      }
    }
  }
'''

new_panel = '''  Component {
    id: agentsPanel
    Flickable {
      contentWidth: width
      contentHeight: agentsColumn.implicitHeight
      clip: true
      ColumnLayout {
        id: agentsColumn
        width: parent.width
        spacing: 10

        PanelButton {
          label: agentsRefreshProc.running ? "Refreshing limits..." : "Refresh limits"
          onPressed: if (!agentsRefreshProc.running) agentsRefreshProc.running = true
        }

        Repeater {
          model: root.state.agents || []
          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: agentColumn.implicitHeight + 20
            radius: 6
            color: "#282828"
            border.color: "#504945"

            ColumnLayout {
              id: agentColumn
              property var currentLimit: root.agentLimit(modelData, false)
              property var weeklyLimit: root.agentLimit(modelData, true)
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 10
              spacing: 8

              Heading { text: root.agentTitle(modelData) }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    Layout.fillWidth: true
                    text: "Current session"
                    color: "#d5c4a1"
                    font.family: "monospace"
                    font.pixelSize: 12
                  }
                  Text {
                    text: agentColumn.currentLimit
                          ? Math.round(root.limitUsed(agentColumn.currentLimit) * 100) + "% used"
                          : "Unavailable"
                    color: root.limitColor(agentColumn.currentLimit)
                    font.family: "monospace"
                    font.pixelSize: 12
                  }
                }
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: 7
                  radius: 4
                  color: "#3c3836"
                  Rectangle {
                    width: parent.width * root.limitUsed(agentColumn.currentLimit)
                    height: parent.height
                    radius: parent.radius
                    color: root.limitColor(agentColumn.currentLimit)
                  }
                }
                Text {
                  text: agentColumn.currentLimit
                        ? root.formatLimitReset(agentColumn.currentLimit.resetsAt)
                        : "Reset time unavailable"
                  color: "#a89984"
                  font.family: "monospace"
                  font.pixelSize: 11
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    Layout.fillWidth: true
                    text: "Weekly limits"
                    color: "#d5c4a1"
                    font.family: "monospace"
                    font.pixelSize: 12
                  }
                  Text {
                    text: agentColumn.weeklyLimit
                          ? Math.round(root.limitUsed(agentColumn.weeklyLimit) * 100) + "% used"
                          : "Unavailable"
                    color: root.limitColor(agentColumn.weeklyLimit)
                    font.family: "monospace"
                    font.pixelSize: 12
                  }
                }
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: 7
                  radius: 4
                  color: "#3c3836"
                  Rectangle {
                    width: parent.width * root.limitUsed(agentColumn.weeklyLimit)
                    height: parent.height
                    radius: parent.radius
                    color: root.limitColor(agentColumn.weeklyLimit)
                  }
                }
                Text {
                  text: agentColumn.weeklyLimit
                        ? root.formatLimitReset(agentColumn.weeklyLimit.resetsAt)
                        : "Reset time unavailable"
                  color: "#a89984"
                  font.family: "monospace"
                  font.pixelSize: 11
                }
              }
            }
          }
        }
      }
    }
  }
'''

replace_once(old_panel, new_panel, "agents panel")

path.write_text(text)
