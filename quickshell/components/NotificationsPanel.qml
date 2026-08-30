import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
  id: view
  required property var shell
  required property var colors
  required property var ui
  required property var historyModel

  spacing: 8
  RowLayout {
    Layout.fillWidth: true
    PanelButton {
      label: view.shell.state.notifications && view.shell.state.notifications.dnd ? "Do Not Disturb: ON" : "Do Not Disturb: OFF"
      onPressed: {
        var next = !(view.shell.state.notifications && view.shell.state.notifications.dnd)
        var n = view.shell.state.notifications || { history: [] }
        n.dnd = next
        view.shell.state.notifications = n
        view.shell.state = Object.assign({}, view.shell.state)
        view.shell.run(["python3", view.shell.backend, "notify", "dnd", next ? "true" : "false"])
      }
    }
    PanelButton {
      label: "Clear"
      onPressed: {
        view.historyModel.clear()
        view.shell.run(["python3", view.shell.backend, "notify", "clear"])
      }
    }
  }
  Flickable {
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: notificationColumn.implicitHeight
    clip: true
    ColumnLayout {
      id: notificationColumn
      width: parent.width
      spacing: 6
      Repeater {
        model: view.historyModel
        Rectangle {
          required property string summary
          required property string body
          required property string app
          Layout.fillWidth: true
          implicitHeight: notifText.implicitHeight + 20
          radius: 5
          color: view.colors.bg
          border.color: view.colors.bgSoft
          Text {
            id: notifText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.verticalCenter: parent.verticalCenter
            text: (app ? app + " · " : "") + summary + (body ? "\n" + body : "")
            textFormat: Text.PlainText
            color: view.colors.fgSoft
            font.family: view.ui.bodyFont
            font.pixelSize: 11
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
