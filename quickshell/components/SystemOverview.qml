import QtQuick
import QtQuick.Layouts

GridLayout {
  id: overview
  required property var shell
  required property var services
  required property var colors
  required property var ui

  columns: 2
  rowSpacing: ui.panelSpacing
  columnSpacing: ui.panelSpacing

  readonly property var entries: [
    { key: "audio", label: "Audio", status: services.muted ? "muted" : String(services.volume) + "%" },
    { key: "network", label: "Network / Wi-Fi", status: shell.state.network && shell.state.network.enabled ? String(shell.state.network.active || "on") : "off" },
    { key: "bluetooth", label: "Bluetooth", status: shell.state.bluetooth && shell.state.bluetooth.powered ? "on" : "off" },
    { key: "power", label: "Power", status: shell.laptop ? String(shell.state.power.battery) + "%" : String(shell.state.power.profile || "power") },
    { key: "agents", label: "AI limits", status: String((shell.state.agents || []).length) + " accounts" },
    { key: "updates", label: "Updates", status: String(shell.state.updates ? shell.state.updates.count || 0 : 0) },
    { key: "notifications", label: "Notifications", status: shell.state.notifications && shell.state.notifications.dnd ? "DND" : String(shell.state.notifications && shell.state.notifications.history ? shell.state.notifications.history.length : 0) },
    { key: "calendar", label: "Calendar", status: Qt.formatDate(shell.clockNow, "ddd d MMM") }
  ]

  Repeater {
    model: overview.entries

    Rectangle {
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: 72
      radius: overview.ui.panelButtonRadius
      color: mouse.containsMouse ? overview.colors.bgHover : overview.colors.bg
      border.color: overview.colors.bgHover
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        Text {
          Layout.fillWidth: true
          text: modelData.label
          color: overview.colors.fgBright
          font.family: overview.ui.bodyFont
          font.bold: true
          font.pixelSize: overview.ui.panelButtonTextSize
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: modelData.status
          color: overview.colors.grayDim
          font.family: overview.ui.bodyFont
          font.pixelSize: overview.ui.panelButtonTextSize - 1
          elide: Text.ElideRight
        }
      }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (modelData.key === "calendar") {
            overview.shell.openCalendar()
          } else {
            // Deliberately switch the existing panel directly. This keeps the
            // overview useful even when Network/Bluetooth are hidden from the
            // desktop top bar on non-laptop machines.
            overview.shell.openPanel = modelData.key
          }
        }
      }
    }
  }
}
