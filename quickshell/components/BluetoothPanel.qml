import QtQuick
import QtQuick.Layouts
import Quickshell

Flickable {
  id: view
  required property var shell
  required property var colors
  required property var ui

  contentWidth: width
  contentHeight: bluetoothColumn.implicitHeight
  clip: true
  ColumnLayout {
    id: bluetoothColumn
    width: parent.width
    spacing: 7
    PanelButton {
      label: view.shell.state.bluetooth && view.shell.state.bluetooth.powered ? "Bluetooth: on" : "Bluetooth: off"
      onPressed: view.shell.backendAction("bluetooth", "toggle", "")
    }
    Heading { text: "Paired devices" }
    Repeater {
      model: view.shell.state.bluetooth ? view.shell.state.bluetooth.devices : []
      PanelButton {
        required property var modelData
        label: (modelData.connected ? "● " : "") + modelData.name +
               (Number(modelData.battery) >= 0 ? "  " + modelData.battery + "%" : "")
        selected: modelData.connected
        onPressed: view.shell.backendAction("bluetooth", modelData.connected ? "disconnect" : "connect", modelData.mac)
      }
    }
  }
}
