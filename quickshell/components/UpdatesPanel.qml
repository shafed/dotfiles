import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
  id: view
  required property var system
  required property var colors
  required property var ui

  spacing: 10
  Text {
    Layout.fillWidth: true
    text: view.system.updates.count === 0
          ? "System is up to date."
          : String(view.system.updates.count) + " package updates available."
    color: view.colors.fgSoft
    font.family: view.ui.bodyFont
    font.pixelSize: 12
    wrapMode: Text.WordWrap
  }
  PanelButton {
    visible: view.system.updates.count > 0
    label: "Open update in kitty"
    onPressed: view.system.updates.runUpdates()
  }
  Item { Layout.fillHeight: true }
}
