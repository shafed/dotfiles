import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
  id: overlay
  required property var shell
  required property var colors
  required property var ui
PanelWindow {
  visible: overlay.shell.osdOpen
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dots-osd"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  Rectangle {
    width: overlay.ui.osdWidth
    height: overlay.ui.osdHeight
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: overlay.ui.osdBottomMargin
    radius: overlay.ui.panelRadius
    color: overlay.colors.bgHard95
    border.color: overlay.colors.bgHover
    RowLayout {
      anchors.fill: parent
      anchors.margins: overlay.ui.panelPadding
      spacing: 12
      Text {
        text: overlay.shell.osdIcon
        color: overlay.colors.yellow
        font.family: overlay.ui.bodyFont
        font.bold: true
        font.pixelSize: 13
      }
      Rectangle {
        visible: overlay.shell.osdHasValue
        Layout.fillWidth: true
        height: 7
        radius: 3
        color: overlay.colors.bgHover
        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, overlay.shell.osdValue / 100))
          height: parent.height
          radius: 3
          color: overlay.colors.green
        }
      }
      Text {
        text: overlay.shell.osdLabel
        color: overlay.colors.fgUi
        font.family: overlay.ui.bodyFont
        font.bold: true
        font.pixelSize: 12
      }
    }
  }
}
}
