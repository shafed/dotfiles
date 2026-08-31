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

  // Keep the visual grouping aligned with the keyboard mnemonic: software and
  // information live on the left, sound/hardware on the right.
  readonly property var entries: [
    { key: "agents", label: "AI limits", chord: "E+R", status: String((shell.state.agents || []).length) + " accounts" },
    { key: "audio", label: "Audio", chord: "Y+U", status: services.muted ? "muted" : String(services.volume) + "%" },
    { key: "updates", label: "Updates", chord: "R+T", status: String(system.updates.count) },
    { key: "network", label: "Network / Wi-Fi", chord: "H+J", status: system.network.enabled ? String(system.network.active || "on") : "off" },
    { key: "notifications", label: "Notifications", chord: "D+F", status: notifications.dnd ? "DND" : String((notifications.history || []).length) },
    { key: "bluetooth", label: "Bluetooth", chord: "L+;", status: system.bluetoothPowered ? "on" : "off" },
    { key: "calendar", label: "Calendar", chord: "X+C", status: Qt.formatDate(shell.clockNow, "ddd d MMM") },
    { key: "power", label: "Power", chord: "C+V", status: shell.laptop ? String(system.batteryPercent) + "%" : String(system.powerProfile || "power") }
  ]

  Text {
    Layout.columnSpan: 2
    Layout.fillWidth: true
    text: "W+E overview  ·  software ←   sound / hardware →"
    color: overview.colors.grayDim
    font.family: overview.ui.bodyFont
    font.pixelSize: overview.ui.panelButtonTextSize - 1
    horizontalAlignment: Text.AlignHCenter
  }

  Repeater {
    model: overview.entries

    Rectangle {
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: 64
      radius: overview.ui.panelButtonRadius
      color: mouse.containsMouse ? overview.colors.bgHover : overview.colors.bg
      border.color: overview.colors.bgHover
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

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
            text: modelData.chord
            color: overview.colors.yellow
            font.family: overview.ui.bodyFont
            font.bold: true
            font.pixelSize: overview.ui.panelButtonTextSize - 1
          }
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
