import QtQuick
import QtQuick.Layouts
import Quickshell

Flickable {
  id: view
  required property var shell
  required property var system
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
      model: view.system.powerProfiles
      PanelButton {
        required property var modelData
        label: String(modelData)
        selected: view.system.powerProfile === String(modelData)
        onPressed: view.system.setPowerProfile(modelData)
      }
    }
    Heading { text: "System" }
    Text {
      Layout.fillWidth: true
      text: (view.system.batteryPercent >= 0
             ? "Battery: " + view.system.batteryPercent + "% (" + view.system.batteryStatus + ")\n"
             : "") + "Uptime: " + view.system.uptime
      color: view.colors.fgSoft
      font.family: view.ui.bodyFont
      font.pixelSize: 12
    }
    RowLayout {
      Layout.fillWidth: true
      PanelButton { label: "Lock"; onPressed: view.shell.run(["hyprlock"]) }
      PanelButton { label: "Suspend"; onPressed: view.shell.run(["systemctl", "suspend"]) }
    }
    RowLayout {
      Layout.fillWidth: true
      PanelButton { label: "Reboot"; onPressed: view.shell.run(["systemctl", "reboot"]) }
      PanelButton { label: "Shutdown"; onPressed: view.shell.run(["systemctl", "poweroff"]) }
    }
  }
}
