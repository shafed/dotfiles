import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
  id: overlay
  required property var shell
  required property var colors
  required property var ui
  required property var toastModel
PanelWindow {
  visible: overlay.toastModel.count > 0
  anchors { top: true; right: true }
  margins.top: overlay.ui.toastTopMargin
  margins.right: overlay.ui.toastRightMargin
  implicitWidth: overlay.ui.toastWidth
  implicitHeight: Math.min(overlay.ui.toastMaxHeight, toastColumn.implicitHeight)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dots-notifications"
  WlrLayershell.layer: WlrLayer.Overlay
  ColumnLayout {
    id: toastColumn
    width: parent.width
    spacing: 6
    Repeater {
      model: overlay.toastModel
      Rectangle {
        required property int index
        required property string summary
        required property string body
        required property string app
        Layout.fillWidth: true
        implicitHeight: toastText.implicitHeight + 24
        color: overlay.colors.bgHard
        border.color: overlay.colors.bgHover
        border.width: 1
        radius: 7
        Text {
          id: toastText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 12
          anchors.verticalCenter: parent.verticalCenter
          text: (app ? app + " · " : "") + summary + (body ? "\n" + body : "")
          textFormat: Text.PlainText
          color: overlay.colors.fgUi
          font.family: overlay.ui.bodyFont
          font.pixelSize: 11
          wrapMode: Text.WordWrap
        }
        MouseArea { anchors.fill: parent; onClicked: overlay.shell.releaseToast(index, false) }
      }
    }
  }
}
}
