import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
  id: overlay
  required property var shell
  required property var colors
  required property var ui

  property string query: ""
  property int selectedIndex: 0
  property string pendingPasteId: ""
  property bool mouseNavigationArmed: false
  property bool mousePositionSampled: false
  property real mouseStartX: 0
  property real mouseStartY: 0
  property var rows: {
    var source = overlay.shell.clipboardRows || []
    var needle = overlay.query.trim().toLowerCase()
    if (!needle) return source
    var result = []
    for (var i = 0; i < source.length; i++) {
      var row = source[i]
      if (String(row.text || "").toLowerCase().indexOf(needle) >= 0)
        result.push(row)
    }
    return result
  }

  function close() {
    overlay.shell.clipboardOpen = false
  }

  function moveSelection(delta) {
    if (!rows || rows.length === 0) return
    selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    clipList.currentIndex = selectedIndex
    clipList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function handleMouseMove(area, mouse, index) {
    var point = area.mapToItem(clipList, mouse.x, mouse.y)
    if (!mousePositionSampled) {
      mouseStartX = point.x
      mouseStartY = point.y
      mousePositionSampled = true
      return
    }

    if (!mouseNavigationArmed) {
      var dx = point.x - mouseStartX
      var dy = point.y - mouseStartY
      if (dx * dx + dy * dy < 16) return
      mouseNavigationArmed = true
    }

    selectedIndex = index
  }

  function pasteSelected() {
    if (!rows || rows.length === 0) return
    var index = Math.max(0, Math.min(rows.length - 1, selectedIndex))
    var row = rows[index]
    pendingPasteId = String(row.id)
    close()
    pasteTimer.restart()
  }

  onQueryChanged: {
    selectedIndex = 0
    clipList.currentIndex = 0
  }

  Timer {
    id: pasteTimer
    interval: 160
    repeat: false
    onTriggered: {
      if (!overlay.pendingPasteId.length) return
      var ident = overlay.pendingPasteId
      overlay.pendingPasteId = ""
      overlay.shell.run(["python3", overlay.shell.backend, "clipboard-paste", ident])
    }
  }

  QuickPicker {
    id: quickPicker
    shell: overlay.shell
    colors: overlay.colors
    ui: overlay.ui
  }

  ScratchOverlay {
    id: scratchOverlay
    shell: overlay.shell
    colors: overlay.colors
    ui: overlay.ui
  }

  Connections {
    target: overlay.shell

    function onClipboardOpenChanged() {
      if (overlay.shell.clipboardOpen) {
        quickPicker.close()
        scratchOverlay.close()
        overlay.query = ""
        overlay.selectedIndex = 0
        overlay.mouseNavigationArmed = false
        overlay.mousePositionSampled = false
        Qt.callLater(function() { searchInput.forceActiveFocus() })
      }
    }

    function onOpenPanelChanged() {
      if (overlay.shell.openPanel !== "") {
        quickPicker.close()
        scratchOverlay.close()
      }
    }
  }

  PanelWindow {
    visible: overlay.shell.clipboardOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: overlay.ui.overlayColor
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
      anchors.fill: parent
      onClicked: overlay.close()
    }

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
          spacing: overlay.ui.panelSpacing

          Text {
            text: "Clipboard"
            color: overlay.colors.yellow
            font.family: overlay.ui.bodyFont
            font.bold: true
            font.pixelSize: 15
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: overlay.ui.pickerInputHeight
            radius: overlay.ui.pickerInputRadius
            color: overlay.colors.bg
            border.color: searchInput.activeFocus ? overlay.colors.yellow : overlay.colors.bgHover
            border.width: 1

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: searchInput.text.length === 0
              text: "Type to filter clipboard…"
              color: overlay.colors.gray
              font.family: overlay.ui.sansFont
              font.pixelSize: overlay.ui.pickerHintSize
            }

            TextInput {
              id: searchInput
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              text: overlay.query
              color: overlay.colors.fgUi
              selectionColor: overlay.colors.bgHover
              selectedTextColor: overlay.colors.fgUi
              font.family: overlay.ui.sansFont
              font.pixelSize: overlay.ui.pickerInputTextSize
              selectByMouse: false
              onTextChanged: overlay.query = text

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  overlay.close()
                  event.accepted = true
                } else if (event.key === Qt.Key_Down ||
                           (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                  overlay.moveSelection(1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Up ||
                           (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                  overlay.moveSelection(-1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  overlay.pasteSelected()
                  event.accepted = true
                }
              }
            }
          }

          ClickButton {
            label: "×"
            onPressed: overlay.close()
          }
        }

        ListView {
          id: clipList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 5
          model: overlay.rows
          currentIndex: overlay.selectedIndex

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: clipList.width
            height: Math.max(44, clipText.implicitHeight + 16)
            radius: overlay.ui.pickerRowRadius
            color: index === overlay.selectedIndex ? overlay.colors.bgSoft : "transparent"
            border.width: index === overlay.selectedIndex ? 1 : 0
            border.color: overlay.colors.bgMuted

            Text {
              id: clipText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              text: String(modelData.text || "")
              color: overlay.colors.fgUi
              font.family: overlay.ui.sansFont
              font.pixelSize: overlay.ui.pickerRowTitleSize
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              onEntered: {
                if (overlay.mouseNavigationArmed)
                  overlay.selectedIndex = index
              }
              onPositionChanged: function(mouse) {
                overlay.handleMouseMove(rowMouse, mouse, index)
              }
              onClicked: {
                overlay.mouseNavigationArmed = true
                overlay.selectedIndex = index
                overlay.pasteSelected()
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: overlay.rows.length + " item" + (overlay.rows.length === 1 ? "" : "s")
            color: overlay.colors.grayDim
            font.family: overlay.ui.bodyFont
            font.pixelSize: 10
          }
          Text {
            text: "↑↓ / ^J^K · Enter paste · Esc"
            color: overlay.colors.gray
            font.family: overlay.ui.bodyFont
            font.pixelSize: 10
          }
        }
      }
    }
  }
}
