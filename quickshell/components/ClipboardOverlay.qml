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
  visible: overlay.shell.clipboardOpen
  anchors { top: true; bottom: true; left: true; right: true }
  color: overlay.ui.overlayColor
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dots-clipboard"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Rectangle {
    width: Math.min(overlay.ui.clipboardMaxWidth, parent.width - overlay.ui.clipboardHorizontalInset)
    height: Math.min(overlay.ui.clipboardMaxHeight, parent.height - overlay.ui.clipboardVerticalInset)
    anchors.centerIn: parent
    color: overlay.colors.bgHard
    border.color: overlay.colors.bgHover
    border.width: 1
    radius: overlay.ui.panelRadius
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: overlay.ui.panelPadding
      spacing: overlay.ui.panelSpacing
      RowLayout {
        Layout.fillWidth: true
        Text {
          Layout.fillWidth: true
          text: "Clipboard"
          color: overlay.colors.yellow
          font.family: overlay.ui.bodyFont
          font.bold: true
          font.pixelSize: 15
        }
        ClickButton { label: "×"; onPressed: overlay.shell.clipboardOpen = false }
      }
      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: clipColumn.implicitHeight
        clip: true
        ColumnLayout {
          id: clipColumn
          width: parent.width
          spacing: 5
          Repeater {
            model: overlay.shell.clipboardRows
            PanelButton {
              required property var modelData
              label: modelData.text
              onPressed: {
                overlay.shell.clipboardOpen = false
                overlay.shell.run(["python3", overlay.shell.backend, "clipboard-paste", String(modelData.id)])
              }
            }
          }
        }
      }
    }
    Keys.onEscapePressed: overlay.shell.clipboardOpen = false
  }
}
}
