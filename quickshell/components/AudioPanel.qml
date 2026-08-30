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
      model: view.services.outputs
      PanelButton {
        required property var modelData
        label: (modelData === view.services.audioSink ? "● " : "  ") + view.services.nodeLabel(modelData)
        selected: modelData === view.services.audioSink
        onPressed: view.services.setDefaultOutput(modelData)
      }
    }

    Heading { text: "Application streams" }
    Repeater {
      model: view.services.streams
      PanelButton {
        required property var modelData
        label: view.services.nodeLabel(modelData) + "  " +
               (modelData.ready && modelData.audio ? Math.round(modelData.audio.volume * 100) : 0) + "%"
        onPressed: view.services.adjustStream(modelData)
      }
    }
  }
}
