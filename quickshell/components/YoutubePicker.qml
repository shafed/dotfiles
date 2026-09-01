import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: youtube
  required property var shell
  required property var colors
  required property var ui

  readonly property string helper: String(Qt.resolvedUrl("../youtube-helper.py")).replace(/^file:\/\//, "")
  readonly property bool channelView: source === "channel-videos" || source === "channel-streams"
  readonly property var selectedRow: rows && rows.length > 0
                                     ? rows[Math.max(0, Math.min(rows.length - 1, selectedIndex))]
                                     : ({})
  readonly property bool normalMode: viMode === "normal"

  property bool open: false
  property string source: "videos"
  property string query: ""
  property var rows: []
  property int selectedIndex: 0
  property bool busy: false
  property bool deep: false
  property bool forceRefresh: false
  property string viMode: "insert"
  property string channelTarget: ""
  property string channelTitle: ""
  property string returnSource: "videos"
  property string returnQuery: ""
  property int enrichPasses: 0

  property bool mouseNavigationArmed: false
  property real pointerStartX: -1
  property real pointerStartY: -1

  function sourceLabel() {
    if (source === "channels") return "Channels"
    if (source === "history") return "History"
    if (source === "later") return "Watch later"
    if (source === "channel-streams") return "Streams"
    if (source === "channel-videos") return deep ? "Deep videos" : "Videos"
    return "Videos"
  }

  function hint() {
    if (normalMode) return "NORMAL · j/k move · g/G top/bottom · i insert · q/Esc back"
    if (source === "history") return "Filter your watch history…"
    if (source === "later") return "Filter Watch later…"
    if (source === "channel-streams") return "Filter live and past streams…"
    if (source === "channel-videos") return deep ? "Filter deep channel history…" : "Filter channel videos…"
    if (source === "channels") return "Search YouTube channels…"
    return "Search YouTube videos…"
  }

  function escapeStyled(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }

  function highlightedText(value, matches) {
    var text = String(value || "")
    if (!matches || matches.length === 0) return escapeStyled(text)
    var marked = ({})
    for (var i = 0; i < matches.length; i++) marked[Number(matches[i])] = true
    var accent = String(youtube.colors.yellow)
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

  function resetPointer() {
    mouseNavigationArmed = false
    pointerStartX = -1
    pointerStartY = -1
  }

  function enterInsert() {
    viMode = "insert"
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function enterNormal() {
    viMode = "normal"
    reloadTimer.stop()
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function close() {
    open = false
    query = ""
    rows = []
    selectedIndex = 0
    busy = false
    deep = false
    forceRefresh = false
    viMode = "insert"
    channelTarget = ""
    channelTitle = ""
    enrichPasses = 0
    resetPointer()
    reloadTimer.stop()
    if (listProc.running) listProc.running = false
  }

  function show() {
    youtube.shell.openPanel = ""
    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "0"])
    source = "videos"
    query = ""
    rows = []
    selectedIndex = 0
    deep = false
    forceRefresh = false
    viMode = "insert"
    channelTarget = ""
    channelTitle = ""
    returnSource = "videos"
    returnQuery = ""
    enrichPasses = 0
    resetPointer()
    open = true
    refreshNow(false)
    enterInsert()
  }

  function toggle() {
    if (open) close()
    else show()
  }

  function setSource(name) {
    source = name
    query = ""
    rows = []
    selectedIndex = 0
    deep = false
    forceRefresh = false
    enrichPasses = 0
    resetPointer()
    enterInsert()
    refreshNow(false)
  }

  function drillChannel(row) {
    returnSource = source
    returnQuery = query
    channelTarget = String(row.target || "")
    channelTitle = String(row.title || row.subtitle || channelTarget)
    Quickshell.execDetached(["python3", helper, "record", String(row.id || "")])
    source = "channel-videos"
    query = ""
    rows = []
    selectedIndex = 0
    deep = false
    forceRefresh = true
    enrichPasses = 0
    resetPointer()
    enterInsert()
    refreshNow(true)
  }

  function backOrClose() {
    if (!channelView) {
      close()
      return
    }
    source = returnSource
    query = returnQuery
    channelTarget = ""
    channelTitle = ""
    deep = false
    forceRefresh = false
    rows = []
    selectedIndex = 0
    resetPointer()
    enterInsert()
    refreshNow(false)
  }

  function toggleStreams() {
    if (!channelView) return
    source = source === "channel-streams" ? "channel-videos" : "channel-streams"
    deep = false
    forceRefresh = false
    query = ""
    rows = []
    selectedIndex = 0
    resetPointer()
    enterInsert()
    refreshNow(false)
  }

  function loadDeep() {
    if (!channelView) return
    source = "channel-videos"
    deep = true
    forceRefresh = false
    query = ""
    rows = []
    selectedIndex = 0
    resetPointer()
    enterInsert()
    refreshNow(false)
  }

  function refreshNow(force) {
    if (!open) return
    if (listProc.running) listProc.running = false
    forceRefresh = force === true
    busy = true
    listProc.running = true
  }

  function selectIndex(index) {
    if (!rows || rows.length === 0) return
    selectedIndex = Math.max(0, Math.min(rows.length - 1, index))
    resultList.currentIndex = selectedIndex
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function moveSelection(delta) {
    selectIndex(selectedIndex + delta)
  }

  function activateSelected() {
    if (!rows || rows.length === 0) {
      if (!channelView) {
        var currentSource = source
        var currentQuery = query
        close()
        Quickshell.execDetached(["python3", helper, "open-search", currentSource, currentQuery])
      }
      return
    }

    var row = selectedRow
    if (String(row.kind || "") === "channel") {
      drillChannel(row)
      return
    }

    var ident = String(row.id || "")
    close()
    Quickshell.execDetached(["python3", helper, "open", ident])
  }

  function handleKey(event) {
    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    var shift = (event.modifiers & Qt.ShiftModifier) !== 0

    if (ctrl && event.key === Qt.Key_V) {
      setSource("videos")
    } else if (ctrl && event.key === Qt.Key_C) {
      setSource("channels")
    } else if (ctrl && event.key === Qt.Key_H) {
      setSource("history")
    } else if (ctrl && event.key === Qt.Key_L) {
      setSource("later")
    } else if (ctrl && event.key === Qt.Key_S && channelView) {
      toggleStreams()
    } else if (ctrl && event.key === Qt.Key_A && channelView) {
      loadDeep()
    } else if (ctrl && event.key === Qt.Key_R) {
      refreshNow(true)
    } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) {
      moveSelection(1)
    } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) {
      moveSelection(-1)
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      activateSelected()
    } else if (event.key === Qt.Key_Escape) {
      if (normalMode) backOrClose()
      else enterNormal()
    } else if (normalMode && event.key === Qt.Key_J) {
      moveSelection(1)
    } else if (normalMode && event.key === Qt.Key_K) {
      moveSelection(-1)
    } else if (normalMode && event.key === Qt.Key_G) {
      selectIndex(shift ? rows.length - 1 : 0)
    } else if (normalMode && event.key === Qt.Key_Q) {
      backOrClose()
    } else if (normalMode && (event.key === Qt.Key_I || event.key === Qt.Key_Slash)) {
      enterInsert()
    } else {
      return false
    }
    event.accepted = true
    return true
  }

  onQueryChanged: {
    selectedIndex = 0
    resultList.currentIndex = 0
    resetPointer()
    if (open && !normalMode) reloadTimer.restart()
  }

  Timer {
    id: reloadTimer
    interval: youtube.source === "videos" || youtube.source === "channels" ? 380 : 100
    repeat: false
    onTriggered: youtube.refreshNow(false)
  }

  Timer {
    interval: 3500
    repeat: true
    running: youtube.open && (youtube.source === "history" || youtube.source === "later") &&
             youtube.enrichPasses < 6
    onTriggered: {
      youtube.enrichPasses += 1
      if (!youtube.busy) youtube.refreshNow(false)
    }
  }

  Process {
    id: listProc
    command: [
      "python3", youtube.helper, "list", youtube.source, youtube.query,
      youtube.channelTarget, youtube.deep ? "deep" : "normal",
      youtube.forceRefresh ? "force" : "cached"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!youtube.open) return
        try {
          youtube.rows = JSON.parse(text)
        } catch (e) {
          youtube.rows = []
          console.warn("youtube picker list:", e)
        }
        youtube.busy = false
        youtube.forceRefresh = false
        youtube.selectedIndex = 0
        resultList.currentIndex = 0
      }
    }
  }

  IpcHandler {
    target: "youtube"
    function toggle(): string {
      youtube.toggle()
      return youtube.open ? "open" : "closed"
    }
    function show(): string {
      youtube.show()
      return "open"
    }
    function close(): string {
      youtube.close()
      return "closed"
    }
  }

  PanelWindow {
    visible: youtube.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: youtube.ui.overlayColor
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-youtube"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
      anchors.fill: parent
      onClicked: youtube.close()
    }

    Rectangle {
      width: Math.min(youtube.ui.youtubePickerMaxWidth, parent.width - youtube.ui.pickerHorizontalInset)
      height: Math.min(youtube.ui.youtubePickerMaxHeight, parent.height - youtube.ui.pickerVerticalInset)
      anchors.centerIn: parent
      color: youtube.colors.bgHard
      border.color: youtube.colors.bgHover
      border.width: 1
      radius: youtube.ui.pickerRadius

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: youtube.ui.pickerPadding
        spacing: youtube.ui.pickerSpacing

        RowLayout {
          Layout.fillWidth: true
          spacing: youtube.ui.pickerSpacing

          Text {
            text: "YouTube"
            color: youtube.colors.yellow
            font.family: youtube.ui.bodyFont
            font.bold: true
            font.pixelSize: youtube.ui.pickerTitleSize
          }

          Text {
            visible: youtube.channelView && youtube.channelTitle.length > 0
            text: "· " + youtube.channelTitle
            color: youtube.colors.fgUi
            font.family: youtube.ui.sansFont
            font.pixelSize: youtube.ui.pickerRowSubtitleSize
            elide: Text.ElideRight
            Layout.maximumWidth: 260
          }

          Rectangle {
            implicitWidth: sourceText.implicitWidth + 16
            implicitHeight: 24
            radius: 5
            color: youtube.colors.bgSoft
            border.color: youtube.colors.bgMuted
            border.width: 1
            Text {
              id: sourceText
              anchors.centerIn: parent
              text: youtube.sourceLabel()
              color: youtube.colors.yellow
              font.family: youtube.ui.bodyFont
              font.pixelSize: 9
              font.bold: true
            }
          }

          Rectangle {
            implicitWidth: modeText.implicitWidth + 16
            implicitHeight: 24
            radius: 5
            color: youtube.normalMode ? youtube.colors.bgHover : youtube.colors.bgSoft
            border.color: youtube.normalMode ? youtube.colors.yellow : youtube.colors.bgMuted
            border.width: 1
            Text {
              id: modeText
              anchors.centerIn: parent
              text: youtube.normalMode ? "NORMAL" : "INSERT"
              color: youtube.normalMode ? youtube.colors.yellow : youtube.colors.gray
              font.family: youtube.ui.bodyFont
              font.pixelSize: 9
              font.bold: true
            }
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: youtube.ui.pickerInputHeight
            radius: youtube.ui.pickerInputRadius
            color: youtube.colors.bg
            border.color: searchInput.activeFocus ? youtube.colors.yellow : youtube.colors.bgHover
            border.width: 1

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: searchInput.text.length === 0
              text: youtube.hint()
              color: youtube.colors.gray
              font.family: youtube.ui.sansFont
              font.pixelSize: youtube.ui.pickerHintSize
              elide: Text.ElideRight
              width: parent.width - 24
            }

            TextInput {
              id: searchInput
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              text: youtube.query
              readOnly: youtube.normalMode
              color: youtube.colors.fgUi
              selectionColor: youtube.colors.bgHover
              selectedTextColor: youtube.colors.fgUi
              font.family: youtube.ui.sansFont
              font.pixelSize: youtube.ui.pickerInputTextSize
              selectByMouse: false
              onTextChanged: youtube.query = text
              Keys.onPressed: function(event) { youtube.handleKey(event) }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: youtube.ui.pickerSpacing

          ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 5
            model: youtube.rows
            currentIndex: youtube.selectedIndex

            delegate: Rectangle {
              required property var modelData
              required property int index
              width: resultList.width
              height: youtube.ui.youtubeRowHeight
              radius: youtube.ui.pickerRowRadius
              color: index === youtube.selectedIndex ? youtube.colors.bgSoft : "transparent"
              border.width: index === youtube.selectedIndex ? 1 : 0
              border.color: youtube.colors.bgMuted

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                  if (youtube.mouseNavigationArmed) youtube.selectedIndex = index
                }
                onPositionChanged: function(mouse) {
                  if (youtube.pointerStartX < 0 || youtube.pointerStartY < 0) {
                    youtube.pointerStartX = mouse.x
                    youtube.pointerStartY = mouse.y
                    return
                  }
                  if (Math.abs(mouse.x - youtube.pointerStartX) +
                      Math.abs(mouse.y - youtube.pointerStartY) >= 4)
                    youtube.mouseNavigationArmed = true
                  if (youtube.mouseNavigationArmed) youtube.selectedIndex = index
                }
                onClicked: {
                  youtube.mouseNavigationArmed = true
                  youtube.selectedIndex = index
                  youtube.activateSelected()
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Text {
                  visible: String(modelData.kind || "") === "video"
                  text: "▶"
                  color: String(modelData.badge || "") === "LIVE" ? youtube.colors.red : youtube.colors.yellow
                  font.family: youtube.ui.bodyFont
                  font.pixelSize: 12
                }

                Text {
                  visible: String(modelData.kind || "") === "channel"
                  text: "◉"
                  color: youtube.colors.aqua
                  font.family: youtube.ui.bodyFont
                  font.pixelSize: 13
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text {
                    Layout.fillWidth: true
                    text: youtube.highlightedText(modelData.title || modelData.id || "", modelData.titleMatches || [])
                    textFormat: Text.StyledText
                    color: youtube.colors.fgUi
                    font.family: youtube.ui.sansFont
                    font.bold: index === youtube.selectedIndex
                    font.pixelSize: youtube.ui.pickerRowTitleSize
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: String(modelData.subtitle || "").length > 0
                    text: youtube.highlightedText(modelData.subtitle || "", modelData.subtitleMatches || [])
                    textFormat: Text.StyledText
                    color: youtube.colors.grayDim
                    font.family: youtube.ui.sansFont
                    font.pixelSize: youtube.ui.pickerRowSubtitleSize
                    elide: Text.ElideRight
                  }
                }

                Text {
                  visible: String(modelData.badge || "").length > 0
                  text: String(modelData.badge || "")
                  color: String(modelData.badge || "") === "LIVE" ? youtube.colors.red
                         : (String(modelData.badge || "") === "CHANNEL" ? youtube.colors.aqua : youtube.colors.yellow)
                  font.family: youtube.ui.bodyFont
                  font.pixelSize: 9
                  font.bold: true
                }
              }
            }
          }

          Rectangle {
            Layout.preferredWidth: youtube.ui.youtubePreviewWidth
            Layout.fillHeight: true
            radius: youtube.ui.pickerRowRadius
            color: youtube.colors.bg
            border.color: youtube.colors.bgHover
            border.width: 1

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 10

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: youtube.ui.youtubePreviewHeight
                radius: 7
                color: youtube.colors.bgHard
                clip: true

                Image {
                  id: previewImage
                  anchors.fill: parent
                  source: String(youtube.selectedRow.thumbnail || "")
                  visible: source.toString().length > 0
                  asynchronous: true
                  cache: true
                  fillMode: Image.PreserveAspectCrop
                  smooth: true
                }
                Text {
                  anchors.centerIn: parent
                  visible: !previewImage.visible
                  text: String(youtube.selectedRow.kind || "") === "channel" ? "◉" : "YT"
                  color: String(youtube.selectedRow.kind || "") === "channel" ? youtube.colors.aqua : youtube.colors.yellow
                  font.family: youtube.ui.bodyFont
                  font.bold: true
                  font.pixelSize: 42
                }
                Text {
                  anchors.centerIn: parent
                  visible: previewImage.visible && previewImage.status === Image.Loading
                  text: "Loading preview…"
                  color: youtube.colors.grayDim
                  font.family: youtube.ui.bodyFont
                  font.pixelSize: 10
                }
              }

              Text {
                Layout.fillWidth: true
                text: youtube.highlightedText(
                        youtube.selectedRow.title || (youtube.busy ? "Loading…" : "No selection"),
                        youtube.selectedRow.titleMatches || [])
                textFormat: Text.StyledText
                color: youtube.colors.fgUi
                font.family: youtube.ui.sansFont
                font.bold: true
                font.pixelSize: 15
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                visible: String(youtube.selectedRow.duration || "").length > 0
                text: "Duration: " + String(youtube.selectedRow.duration || "")
                color: youtube.colors.grayDim
                font.family: youtube.ui.bodyFont
                font.pixelSize: 10
              }
              Text {
                Layout.fillWidth: true
                visible: String(youtube.selectedRow.channel || "").length > 0
                text: "Channel: " + String(youtube.selectedRow.channel || "")
                color: youtube.colors.grayDim
                font.family: youtube.ui.bodyFont
                font.pixelSize: 10
                elide: Text.ElideRight
              }

              Item { Layout.fillHeight: true }

              Text {
                Layout.fillWidth: true
                visible: String(youtube.selectedRow.kind || "") === "channel"
                text: "Enter opens this channel inside the picker."
                color: youtube.colors.aqua
                font.family: youtube.ui.bodyFont
                font.pixelSize: 10
                wrapMode: Text.Wrap
              }
              Text {
                Layout.fillWidth: true
                visible: youtube.channelView
                text: "^S videos/streams · ^A deep videos · ^R force refresh"
                color: youtube.colors.yellow
                font.family: youtube.ui.bodyFont
                font.pixelSize: 10
                wrapMode: Text.Wrap
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: youtube.busy ? "Loading…" :
                  (youtube.rows.length + " result" + (youtube.rows.length === 1 ? "" : "s"))
            color: youtube.colors.grayDim
            font.family: youtube.ui.bodyFont
            font.pixelSize: 10
          }
          Text {
            text: youtube.normalMode
                  ? "j/k · g/G · i insert · q/Esc back · Enter open"
                  : (youtube.channelView
                     ? "^S streams · ^A deep · ^R refresh · Esc normal · Enter"
                     : "^V videos · ^C channels · ^H history · ^L later · ^R refresh · Esc normal")
            color: youtube.colors.gray
            font.family: youtube.ui.bodyFont
            font.pixelSize: 10
          }
        }
      }
    }
  }
}
