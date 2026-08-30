import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
  id: view
  required property var shell
  required property var colors
  required property var ui

  spacing: 10
  Text {
    Layout.fillWidth: true
    text: Number(view.shell.state.updates ? view.shell.state.updates.count : 0) === 0
          ? "System is up to date."
          : String(view.shell.state.updates.count) + " package updates available."
    color: view.colors.fgSoft
    font.family: view.ui.bodyFont
    font.pixelSize: 12
    wrapMode: Text.WordWrap
  }
  PanelButton {
    visible: Number(view.shell.state.updates ? view.shell.state.updates.count : 0) > 0
    label: "Open update in kitty"
    onPressed: view.shell.backendAction("updates", "run", "")
  }
  Item { Layout.fillHeight: true }
}
