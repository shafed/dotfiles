import QtQuick
import QtQuick.Layouts
import Quickshell

Flickable {
  id: view
  required property var shell
  required property var services
  required property var colors
  required property var ui

  contentWidth: width
  contentHeight: audioColumn.implicitHeight
  clip: true
  ColumnLayout {
    id: audioColumn
    width: parent.width
    spacing: 7

    Heading { text: "Master" }
    RowLayout {
      Layout.fillWidth: true
      PanelButton {
        Layout.fillWidth: true
        label: view.services.muted ? "Unmute" : "Mute"
        onPressed: view.services.toggleMute()
      }
      PanelButton {
        Layout.preferredWidth: 74
        label: "-5%"
        onPressed: view.services.adjustVolume(-0.05)
      }
      PanelButton {
        Layout.preferredWidth: 74
        label: "+5%"
        onPressed: view.services.adjustVolume(0.05)
      }
    }

    Heading { text: "Outputs" }
    Repeater {
      model: view.shell.state.audio ? view.shell.state.audio.sinks : []
      PanelButton {
        required property var modelData
        label: (modelData.default ? "● " : "  ") + modelData.name
        selected: modelData.default
        onPressed: view.shell.backendAction("audio", "sink", modelData.id)
      }
    }

    Heading { text: "Application streams" }
    Repeater {
      model: view.shell.state.audio ? view.shell.state.audio.streams : []
      PanelButton {
        required property var modelData
        label: modelData.name + "  " + modelData.volume + "%"
        onPressed: {
          var next = modelData.volume >= 90 ? 50 : modelData.volume + 10
          view.shell.backendAction("audio", "stream:" + modelData.id, next)
        }
      }
    }
  }
}
