import QtQuick
import QtQuick.Layouts
import Quickshell

Flickable {
  id: view
  required property var shell
  required property var colors
  required property var ui

  contentWidth: width
  contentHeight: powerColumn.implicitHeight
  clip: true
  ColumnLayout {
    id: powerColumn
    width: parent.width
    spacing: 7
    Heading { text: "Power profile" }
    Repeater {
      model: view.shell.state.power ? view.shell.state.power.profiles : []
      PanelButton {
        required property var modelData
        label: String(modelData)
        selected: view.shell.state.power && view.shell.state.power.profile === String(modelData)
        onPressed: view.shell.backendAction("power", "profile", modelData)
      }
    }
    Heading { text: "System" }
    Text {
      Layout.fillWidth: true
      text: (view.shell.state.power && Number(view.shell.state.power.battery) >= 0
             ? "Battery: " + view.shell.state.power.battery + "% (" + view.shell.state.power.status + ")\n"
             : "") + "Uptime: " + (view.shell.state.power ? view.shell.state.power.uptime : "")
      color: view.colors.fgSoft
      font.family: view.ui.bodyFont
      font.pixelSize: 12
    }
    RowLayout {
      Layout.fillWidth: true
      PanelButton { label: "Lock"; onPressed: view.shell.backendAction("power", "lock", "") }
      PanelButton { label: "Suspend"; onPressed: view.shell.backendAction("power", "suspend", "") }
    }
    RowLayout {
      Layout.fillWidth: true
      PanelButton { label: "Reboot"; onPressed: view.shell.backendAction("power", "reboot", "") }
      PanelButton { label: "Shutdown"; onPressed: view.shell.backendAction("power", "shutdown", "") }
    }
  }
}
