import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../config" as Config

Item {
  id: picker

  Config.Colors { id: colors }
  Config.UiConfig { id: ui }

  readonly property string helper: Quickshell.env("HOME") + "/.config/quickshell/palette-helper.py"

  property bool open: false
  property string query: ""
  property string processQuery: ""
  property int selectedIndex: 0
  property var rows: []

  function escapeStyled(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }

  // Same scheme as YoutubePicker.qml/QuickPicker.qml: palette-helper.py
  // returns the character indices its fuzzy matcher actually used, so
  // highlighting here always agrees with why a row ranked where it did.
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

  function requestSearch(immediate) {
    if (immediate) {
      searchDelay.stop()
      startSearch()
    } else {
      searchDelay.restart()
    }
  }

  function startSearch() {
    if (!open || searchProc.running) return
    processQuery = query
    searchProc.running = true
  }

  function show() {
    query = ""
    selectedIndex = 0
    rows = []
    open = true
    if (!syncProc.running) syncProc.running = true
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function close() {
    open = false
    query = ""
    selectedIndex = 0
    rows = []
    searchDelay.stop()
  }

  function toggle() {
    if (open) close()
    else show()
  }

  function moveSelection(delta) {
    if (!rows || rows.length === 0) return
    selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    bookmarkList.currentIndex = selectedIndex
    bookmarkList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function activateSelected() {
    if (!rows || rows.length === 0) return
    var row = rows[Math.max(0, Math.min(rows.length - 1, selectedIndex))]
    close()
    Quickshell.execDetached(["python3", helper, "open-bookmark", String(row.name || ""), String(row.url || "")])
  }

  onQueryChanged: {
    selectedIndex = 0
    bookmarkList.currentIndex = 0
    if (bookmarkList.count > 0) bookmarkList.positionViewAtBeginning()
    if (open) requestSearch(false)
  }

  Timer {
    id: searchDelay
    interval: 45
    repeat: false
    onTriggered: picker.startSearch()
  }

  Process {
    id: syncProc
    command: ["python3", picker.helper, "sync-bookmarks"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (picker.open) picker.requestSearch(true)
      }
    }
  }

  Process {
    id: searchProc
    command: ["python3", picker.helper, "search-bookmarks", picker.processQuery]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (picker.open && picker.processQuery === picker.query) {
          try { picker.rows = JSON.parse(text) } catch (e) { picker.rows = [] }
          picker.selectedIndex = 0
          bookmarkList.currentIndex = 0
          if (bookmarkList.count > 0) bookmarkList.positionViewAtBeginning()
        }
        if (picker.open && picker.processQuery !== picker.query)
          Qt.callLater(function() { picker.startSearch() })
      }
    }
  }

  IpcHandler {
    target: "bookmarks"
    function toggle(): string {
      picker.toggle()
      return picker.open ? "open" : "closed"
    }
    function show(): string {
      picker.show()
      return "open"
    }
    function close(): string {
      picker.close()
      return "closed"
    }
  }

  PanelWindow {
    visible: picker.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: ui.overlayColor
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-bookmarks"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      width: Math.min(ui.pickerMaxWidth, parent.width - ui.pickerHorizontalInset)
      height: Math.min(ui.pickerMaxHeight, parent.height - ui.pickerVerticalInset)
      anchors.centerIn: parent
      color: colors.bgHard
      border.color: colors.bgHover
      border.width: 1
      radius: ui.pickerRadius

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: ui.pickerPadding
        spacing: ui.pickerSpacing

        RowLayout {
          Layout.fillWidth: true
          spacing: ui.pickerSpacing

          Text {
            text: "Bookmarks"
            color: colors.yellow
            font.family: ui.bodyFont
            font.bold: true
            font.pixelSize: ui.pickerTitleSize
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: ui.pickerInputHeight
            radius: ui.pickerInputRadius
            color: colors.bg
            border.color: searchInput.activeFocus ? colors.yellow : colors.bgHover
            border.width: 1

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: searchInput.text.length === 0
              text: "Recent bookmarks — type for fzf search…"
              color: colors.gray
              font.family: ui.sansFont
              font.pixelSize: ui.pickerHintSize
            }

            TextInput {
              id: searchInput
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              text: picker.query
              color: colors.fgUi
              selectionColor: colors.bgHover
              selectedTextColor: colors.fgUi
              font.family: ui.sansFont
              font.pixelSize: ui.pickerInputTextSize
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
                } else if (event.key === Qt.Key_Home) {
                  picker.selectedIndex = 0
                  bookmarkList.positionViewAtBeginning()
                  event.accepted = true
                } else if (event.key === Qt.Key_End && picker.rows.length > 0) {
                  picker.selectedIndex = picker.rows.length - 1
                  bookmarkList.positionViewAtEnd()
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  picker.activateSelected()
                  event.accepted = true
                }
              }
            }
          }
        }

        ListView {
          id: bookmarkList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 4
          model: picker.rows
          currentIndex: picker.selectedIndex

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: bookmarkList.width
            height: ui.pickerRowHeight
            radius: ui.pickerRowRadius
            color: index === picker.selectedIndex ? colors.bgSoft : "transparent"
            border.width: index === picker.selectedIndex ? 1 : 0
            border.color: colors.bgMuted

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 12
              spacing: 10

              Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 6
                color: colors.bg
                border.color: colors.bgHover
                border.width: 1

                Image {
                  anchors.fill: parent
                  anchors.margins: 4
                  source: String(modelData.icon || "")
                  visible: source.toString().length > 0
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  asynchronous: true
                }

                Text {
                  anchors.centerIn: parent
                  visible: String(modelData.icon || "").length === 0
                  text: String(modelData.name || modelData.url || "?").charAt(0).toUpperCase()
                  color: colors.grayDim
                  font.family: ui.sansFont
                  font.bold: true
                  font.pixelSize: ui.pickerRowTitleSize
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: picker.highlightedText(modelData.name || modelData.url || "", modelData.nameMatches || [])
                  textFormat: Text.StyledText
                  color: colors.fgUi
                  font.family: ui.sansFont
                  font.bold: index === picker.selectedIndex
                  font.pixelSize: ui.pickerRowTitleSize
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  text: picker.highlightedText(modelData.url || "", modelData.urlMatches || [])
                  textFormat: Text.StyledText
                  color: colors.grayDim
                  font.family: ui.sansFont
                  font.pixelSize: ui.pickerRowSubtitleSize
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: picker.rows.length + (picker.query.trim() ? " fzf + usage matches" : " recent")
            color: colors.gray
            font.family: ui.bodyFont
            font.pixelSize: ui.pickerFooterSize
          }
          Text {
            text: "↑↓ / Ctrl-JK  select   Enter  open/focus   Esc  close"
            color: colors.gray
            font.family: ui.bodyFont
            font.pixelSize: ui.pickerFooterSize
          }
        }
      }
    }
  }
}
