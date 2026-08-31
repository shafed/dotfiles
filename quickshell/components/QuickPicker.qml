import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: picker
  required property var shell
  required property var colors
  required property var ui

  readonly property string helper: picker.shell.home + "/github/dotfiles/quickshell/picker-helper.py"

  property bool open: false
  property string mode: "projects"
  property string query: ""
  property var rows: []
  property int selectedIndex: 0
  property bool busy: false
  property string deleteName: ""

  function titleForMode() {
    if (mode === "sessions") return "Sessions"
    return "Projects"
  }

  function hintForMode() {
    if (mode === "sessions") return "Filter open kitty sessions…"
    return "Named sessions, zoxide directories, SSH hosts…"
  }

  function escapeStyled(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }

  // Same scheme as YoutubePicker.qml: picker-helper.py returns the character
  // indices its fuzzy matcher actually used, so highlighting here always
  // agrees with why a row ranked where it did.
  function highlightedText(value, matches) {
    var text = String(value || "")
    if (!matches || matches.length === 0) return escapeStyled(text)
    var marked = ({})
    for (var i = 0; i < matches.length; i++)
      marked[Number(matches[i])] = true
    var accent = String(picker.colors.yellow)
    var out = ""
    var active = false
    for (var j = 0; j < text.length; j++) {
      var shouldHighlight = marked[j] === true
      if (shouldHighlight !== active) {
        out += shouldHighlight ? '<font color="' + accent + '"><b>' : "</b></font>"
        active = shouldHighlight
      }
      out += escapeStyled(text.charAt(j))
    }
    if (active) out += "</b></font>"
    return out
  }

  function close() {
    open = false
    query = ""
    rows = []
    selectedIndex = 0
    busy = false
    if (listProc.running) listProc.running = false
  }

  function show(name) {
    picker.shell.openPanel = ""
    mode = name
    query = ""
    rows = []
    selectedIndex = 0
    open = true
    refreshNow()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function toggle(name) {
    if (open && mode === name) close()
    else show(name)
  }

  function refreshNow() {
    if (!open) return
    if (listProc.running) listProc.running = false
    busy = true
    listProc.running = true
  }

  function moveSelection(delta) {
    if (!rows || rows.length === 0) return
    selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    resultList.currentIndex = selectedIndex
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function activateSelected() {
    if (!rows || rows.length === 0) return
    var index = Math.max(0, Math.min(rows.length - 1, selectedIndex))
    var row = rows[index]
    var provider = mode
    close()
    Quickshell.execDetached(["python3", helper, "open", provider, String(row.id)])
  }

  function deleteSelected() {
    if (mode !== "sessions" || !rows || rows.length === 0 || deleteProc.running) return
    var index = Math.max(0, Math.min(rows.length - 1, selectedIndex))
    deleteName = String(rows[index].id)
    deleteProc.running = true
  }

  onQueryChanged: {
    selectedIndex = 0
    resultList.currentIndex = 0
    if (open) reloadTimer.restart()
  }

  Timer {
    id: reloadTimer
    interval: 90
    repeat: false
    onTriggered: picker.refreshNow()
  }

  Process {
    id: listProc
    command: ["python3", picker.helper, "list", picker.mode, picker.query]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!picker.open) return
        try {
          picker.rows = JSON.parse(text)
        } catch (e) {
          picker.rows = []
          console.warn("quickpicker list:", e)
        }
        picker.busy = false
        picker.selectedIndex = 0
        resultList.currentIndex = 0
      }
    }
  }

  Process {
    id: deleteProc
    command: ["python3", picker.helper, "delete", "sessions", picker.deleteName]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        picker.deleteName = ""
        if (picker.open) picker.refreshNow()
      }
    }
  }

  IpcHandler {
    target: "quickpicker"
    function toggle(name: string): string {
      picker.toggle(name)
      return picker.open ? picker.mode : "closed"
    }
    function show(name: string): string {
      picker.show(name)
      return picker.mode
    }
    function close(): string {
      picker.close()
      return "closed"
    }
  }

  PanelWindow {
    visible: picker.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: picker.ui.overlayColor
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-quickpicker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
      anchors.fill: parent
      onClicked: picker.close()
    }

    Rectangle {
      width: Math.min(picker.ui.pickerMaxWidth, parent.width - picker.ui.pickerHorizontalInset)
      height: Math.min(picker.ui.pickerMaxHeight, parent.height - picker.ui.pickerVerticalInset)
      anchors.centerIn: parent
      color: picker.colors.bgHard
      border.color: picker.colors.bgHover
      border.width: 1
      radius: picker.ui.pickerRadius

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: picker.ui.pickerPadding
        spacing: picker.ui.pickerSpacing

        RowLayout {
          Layout.fillWidth: true
          spacing: picker.ui.pickerSpacing

          Text {
            text: picker.titleForMode()
            color: picker.colors.yellow
            font.family: picker.ui.bodyFont
            font.bold: true
            font.pixelSize: picker.ui.pickerTitleSize
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: picker.ui.pickerInputHeight
            radius: picker.ui.pickerInputRadius
            color: picker.colors.bg
            border.color: searchInput.activeFocus ? picker.colors.yellow : picker.colors.bgHover
            border.width: 1

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: searchInput.text.length === 0
              text: picker.hintForMode()
              color: picker.colors.gray
              font.family: picker.ui.sansFont
              font.pixelSize: picker.ui.pickerHintSize
              elide: Text.ElideRight
              width: parent.width - 24
            }

            TextInput {
              id: searchInput
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              text: picker.query
              color: picker.colors.fgUi
              selectionColor: picker.colors.bgHover
              selectedTextColor: picker.colors.fgUi
              font.family: picker.ui.sansFont
              font.pixelSize: picker.ui.pickerInputTextSize
              selectByMouse: false
              onTextChanged: picker.query = text

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  picker.close()
                  event.accepted = true
                } else if (event.key === Qt.Key_Down ||
                           (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                  picker.moveSelection(1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Up ||
                           (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                  picker.moveSelection(-1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  picker.activateSelected()
                  event.accepted = true
                } else if (picker.mode === "sessions" &&
                           (event.key === Qt.Key_Delete ||
                            (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)))) {
                  picker.deleteSelected()
                  event.accepted = true
                } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
                  picker.refreshNow()
                  event.accepted = true
                }
              }
            }
          }
        }

        ListView {
          id: resultList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          interactive: false
          spacing: 4
          model: picker.rows
          currentIndex: picker.selectedIndex

          delegate: Rectangle {
            required property var modelData
            required property int index

            width: resultList.width
            height: picker.ui.pickerRowHeight
            radius: picker.ui.pickerRowRadius
            color: index === picker.selectedIndex ? picker.colors.bgSoft : "transparent"
            border.width: index === picker.selectedIndex ? 1 : 0
            border.color: picker.colors.bgMuted

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 10

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                  Layout.fillWidth: true
                  text: picker.highlightedText(modelData.title || modelData.id || "", modelData.titleMatches || [])
                  textFormat: Text.StyledText
                  color: picker.colors.fgUi
                  font.family: picker.ui.sansFont
                  font.bold: index === picker.selectedIndex
                  font.pixelSize: picker.ui.pickerRowTitleSize
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  visible: String(modelData.subtitle || "").length > 0
                  text: picker.highlightedText(modelData.subtitle || "", modelData.subtitleMatches || [])
                  textFormat: Text.StyledText
                  color: picker.colors.grayDim
                  font.family: picker.ui.sansFont
                  font.pixelSize: picker.ui.pickerRowSubtitleSize
                  elide: Text.ElideMiddle
                }
              }

              Text {
                visible: String(modelData.badge || "").length > 0
                text: String(modelData.badge || "")
                color: String(modelData.badge || "") === "CURRENT" ? picker.colors.green : picker.colors.yellow
                font.family: picker.ui.bodyFont
                font.pixelSize: 9
                font.bold: true
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true

          Text {
            Layout.fillWidth: true
            text: picker.busy ? "Loading…" :
                  (picker.rows.length + " result" + (picker.rows.length === 1 ? "" : "s"))
            color: picker.colors.grayDim
            font.family: picker.ui.bodyFont
            font.pixelSize: 10
          }

          Text {
            text: picker.mode === "sessions"
                  ? "↑↓ / ^J^K · Enter open · ^D delete · Esc"
                  : "↑↓ / ^J^K · Enter open · Esc"
            color: picker.colors.gray
            font.family: picker.ui.bodyFont
            font.pixelSize: 10
          }
        }
      }
    }
  }
}
