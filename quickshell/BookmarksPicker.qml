import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: picker

  readonly property string helper: Quickshell.env("HOME") + "/.config/quickshell/palette-helper.py"

  property bool open: false
  property string query: ""
  property string processQuery: ""
  property int selectedIndex: 0
  property var rows: []

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
    color: "#99000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-bookmarks"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      width: Math.min(720, parent.width - 80)
      height: Math.min(600, parent.height - 100)
      anchors.centerIn: parent
      color: "#1d2021"
      border.color: "#504945"
      border.width: 1
      radius: 10

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            text: "Bookmarks"
            color: "#d8a657"
            font.family: "monospace"
            font.bold: true
            font.pixelSize: 15
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 6
            color: "#282828"
            border.color: searchInput.activeFocus ? "#d8a657" : "#504945"
            border.width: 1

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: searchInput.text.length === 0
              text: "Recent bookmarks — type for fzf search…"
              color: "#928374"
              font.family: "sans-serif"
              font.pixelSize: 12
            }

            TextInput {
              id: searchInput
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              text: picker.query
              color: "#ebdbb2"
              selectionColor: "#504945"
              selectedTextColor: "#ebdbb2"
              font.family: "sans-serif"
              font.pixelSize: 13
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
            height: 54
            radius: 7
            color: index === picker.selectedIndex ? "#3c3836" : "transparent"
            border.width: index === picker.selectedIndex ? 1 : 0
            border.color: "#665c54"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 12
              spacing: 10

              Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 6
                color: "#282828"
                border.color: "#504945"
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
                  color: "#a89984"
                  font.family: "sans-serif"
                  font.bold: true
                  font.pixelSize: 13
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: String(modelData.name || modelData.url || "")
                  color: "#ebdbb2"
                  font.family: "sans-serif"
                  font.bold: index === picker.selectedIndex
                  font.pixelSize: 13
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  text: String(modelData.url || "")
                  color: "#a89984"
                  font.family: "sans-serif"
                  font.pixelSize: 11
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
            color: "#928374"
            font.family: "monospace"
            font.pixelSize: 10
          }
          Text {
            text: "↑↓ / Ctrl-JK  select   Enter  open/focus   Esc  close"
            color: "#928374"
            font.family: "monospace"
            font.pixelSize: 10
          }
        }
      }
    }
  }
}
