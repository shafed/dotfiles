import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: scratch
  required property var shell
  required property var colors
  required property var ui

  readonly property string helper: scratch.shell.home + "/github/dotfiles/quickshell/picker-helper.py"

  property bool open: false
  property string targetAddress: ""
  property string draft: ""

  function close() {
    open = false
  }

  function show(target) {
    scratch.shell.clipboardOpen = false
    scratch.shell.openPanel = ""
    targetAddress = target === "none" ? "" : target
    open = true
    Qt.callLater(function() {
      editor.forceActiveFocus()
      editor.cursorPosition = editor.length
    })
  }

  function toggle(target) {
    if (open) close()
    else show(target)
  }

  function pasteAndClose() {
    var text = editor.text
    draft = text
    open = false
    if (!text.length) return
    Quickshell.execDetached([
      "python3", helper, "scratch-paste",
      targetAddress.length ? targetAddress : "none",
      text
    ])
    draft = ""
  }

  IpcHandler {
    target: "scratch"
    function toggle(target: string): string {
      scratch.toggle(target)
      return scratch.open ? "open" : "closed"
    }
    function show(target: string): string {
      scratch.show(target)
      return "open"
    }
    function close(): string {
      scratch.close()
      return "closed"
    }
  }

  PanelWindow {
    visible: scratch.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: scratch.ui.overlayColor
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-scratch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
      anchors.fill: parent
      onClicked: scratch.close()
    }

    Rectangle {
      width: Math.min(scratch.ui.pickerMaxWidth, parent.width - scratch.ui.pickerHorizontalInset)
      height: Math.min(520, parent.height - scratch.ui.pickerVerticalInset)
      anchors.centerIn: parent
      color: scratch.colors.bgHard
      border.color: scratch.colors.bgHover
      border.width: 1
      radius: scratch.ui.pickerRadius

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: scratch.ui.pickerPadding
        spacing: scratch.ui.pickerSpacing

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: "Scratch"
            color: scratch.colors.yellow
            font.family: scratch.ui.bodyFont
            font.bold: true
            font.pixelSize: scratch.ui.pickerTitleSize
          }
          Text {
            text: "Ctrl+Enter paste · Esc hide"
            color: scratch.colors.gray
            font.family: scratch.ui.bodyFont
            font.pixelSize: 10
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: scratch.ui.pickerInputRadius
          color: scratch.colors.bg
          border.color: editor.activeFocus ? scratch.colors.yellow : scratch.colors.bgHover
          border.width: 1
          clip: true

          Flickable {
            id: editorFlick
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: Math.max(height, editor.implicitHeight)
            clip: true

            TextEdit {
              id: editor
              width: editorFlick.width
              height: Math.max(editorFlick.height, implicitHeight)
              text: scratch.draft
              color: scratch.colors.fgUi
              selectionColor: scratch.colors.bgHover
              selectedTextColor: scratch.colors.fgUi
              font.family: scratch.ui.monoFont
              font.pixelSize: 15
              wrapMode: TextEdit.Wrap
              selectByMouse: true
              onTextChanged: scratch.draft = text

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  scratch.close()
                  event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                           (event.modifiers & Qt.ControlModifier)) {
                  scratch.pasteAndClose()
                  event.accepted = true
                }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          text: "Super+N toggles. Draft is kept while hidden and cleared after paste."
          color: scratch.colors.grayDim
          font.family: scratch.ui.bodyFont
          font.pixelSize: 10
        }
      }
    }
  }
}
