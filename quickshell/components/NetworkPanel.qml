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
  contentHeight: networkColumn.implicitHeight
  clip: true
  ColumnLayout {
    id: networkColumn
    width: parent.width
    spacing: 7
    RowLayout {
      Layout.fillWidth: true
      PanelButton {
        label: view.system.network.enabled ? "Wi-Fi: on" : "Wi-Fi: off"
        onPressed: view.system.network.toggle()
      }
      PanelButton {
        label: "nmtui"
        onPressed: view.system.network.openSettings()
      }
    }
    Heading { text: "Networks" }
    Repeater {
      model: view.system.network.networks
      PanelButton {
        required property var modelData
        label: (modelData.active ? "● " : "") + modelData.ssid + "  " + modelData.signal + "%  " + modelData.security
        selected: modelData.active
        onPressed: view.system.network.connectNetwork(modelData.ssid)
      }
    }
  }
}
