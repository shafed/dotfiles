import QtQuick
import QtQuick.Layouts

GridLayout {
  id: overview
  required property var shell
  required property var services
  required property var system
  required property var notifications
  required property var colors
  required property var ui

  columns: 2
  rowSpacing: ui.panelSpacing
  columnSpacing: ui.panelSpacing

  readonly property var entries: [
    { key: "audio", label: "Audio", status: services.muted ? "muted" : String(services.volume) + "%" },
    { key: "network", label: "Network / Wi-Fi", status: system.network.enabled ? String(system.network.active || "on") : "off" },
    { key: "bluetooth", label: "Bluetooth", status: system.bluetoothPowered ? "on" : "off" },
    { key: "power", label: "Power", status: shell.laptop ? String(system.batteryPercent) + "%" : String(system.powerProfile || "power") },
    { key: "agents", label: "AI limits", status: String((shell.state.agents || []).length) + " accounts" },
    { key: "updates", label: "Updates", status: String(system.updates.count) },
    { key: "notifications", label: "Notifications", status: notifications.dnd ? "DND" : String((notifications.history || []).length) },
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
            overview.shell.openPanel = modelData.key
          }
        }
      }
    }
  }
}
