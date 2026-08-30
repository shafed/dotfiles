import QtQuick
import QtQuick.Layouts
import Quickshell

Flickable {
  id: view
  required property var shell
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
        label: view.shell.state.network && view.shell.state.network.enabled ? "Wi-Fi: on" : "Wi-Fi: off"
        onPressed: view.shell.backendAction("network", "toggle", "")
      }
      PanelButton {
        label: "nmtui"
        onPressed: view.shell.backendAction("network", "settings", "")
      }
    }
    Heading { text: "Networks" }
    Repeater {
      model: view.shell.state.network ? view.shell.state.network.networks : []
      PanelButton {
        required property var modelData
        label: (modelData.active ? "● " : "") + modelData.ssid + "  " + modelData.signal + "%  " + modelData.security
        selected: modelData.active
        onPressed: view.shell.backendAction("network", "connect", modelData.ssid)
      }
    }
  }
}
