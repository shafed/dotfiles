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
  contentHeight: bluetoothColumn.implicitHeight
  clip: true
  ColumnLayout {
    id: bluetoothColumn
    width: parent.width
    spacing: 7
    PanelButton {
      label: view.system.bluetoothPowered ? "Bluetooth: on" : "Bluetooth: off"
      onPressed: view.system.toggleBluetooth()
    }
    Heading { text: "Paired devices" }
    Repeater {
      model: view.system.bluetoothDevices
      PanelButton {
        required property var modelData
        label: (modelData.connected ? "● " : "") + modelData.name +
               (modelData.batteryAvailable ? "  " + Math.round(modelData.battery * 100) + "%" : "")
        selected: modelData.connected
        onPressed: view.system.toggleBluetoothDevice(modelData)
      }
    }
  }
}
