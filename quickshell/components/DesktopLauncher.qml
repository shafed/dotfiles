import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../config" as Config

Item {
  id: launcher

  Config.Colors { id: colors }
  Config.UiConfig { id: ui }

  readonly property string usageDir: String(Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/apps-fzf"
  readonly property string usagePath: usageDir + "/usage.tsv"

  property bool open: false
  property string query: ""
  property int selectedIndex: 0
  property int appRevision: 0
  property var usage: ({})
  property bool usageReady: false
  property var pendingUsageDeltas: ({})
  property var rows: {
    appRevision
    usage
    return sortedEntries(query)
  }

  function normalize(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/\.desktop$/, "")
      .replace(/[._\-\s]/g, "")
  }

  function usageStorageKey(value) {
    return String(value || "").trim().toLowerCase().replace(/\.desktop$/, "")
  }

  function usageKey(entry) {
    return usageStorageKey((entry && entry.id) || "")
  }

  function usageCount(entry) {
    return Number(usage[usageKey(entry)] || 0)
  }

  function usageBonus(entry) {
    var count = usageCount(entry)
    if (count <= 0) return 0
    return Math.min(3600, Math.log(count + 1) / Math.LN2 * 1200)
  }

  function parseUsageText(text) {
    var result = ({})
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var tab = line.indexOf("\t")
      if (tab < 0) continue
      var key = usageStorageKey(line.slice(0, tab))
      var count = parseInt(line.slice(tab + 1), 10)
      if (!key || isNaN(count)) continue
      result[key] = Math.max(Number(result[key] || 0), count)
    }
    return result
  }

  function serializeUsage(values) {
    var keys = Object.keys(values || {}).filter(function(key) { return !!key }).sort()
    var lines = []
    for (var i = 0; i < keys.length; i++)
      lines.push(keys[i] + ".desktop\t" + String(Math.max(0, Math.floor(Number(values[keys[i]]) || 0))))
    return lines.length ? lines.join("\n") + "\n" : ""
  }

  function loadUsage() {
    try { usage = parseUsageText(usageFile.text()) } catch (e) { usage = ({}) }
  }

  function saveUsage() {
    if (!usageReady) return
    usageFile.setText(serializeUsage(usage))
  }

  function finishUsageInit() {
    var disk = ({})
    try { disk = parseUsageText(usageFile.text()) } catch (e) {}
    var pending = pendingUsageDeltas || ({})
    var keys = Object.keys(pending)
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i]
      disk[key] = Number(disk[key] || 0) + Number(pending[key] || 0)
    }
    usageReady = true
    usage = disk
    pendingUsageDeltas = ({})
    if (keys.length > 0) saveUsage()
  }

  function recordUse(entry) {
    var key = usageKey(entry)
    if (!key) return
    var next = Object.assign({}, usage)
    next[key] = Number(next[key] || 0) + 1
    usage = next

    if (!usageReady) {
      var pending = Object.assign({}, pendingUsageDeltas)
      pending[key] = Number(pending[key] || 0) + 1
      pendingUsageDeltas = pending
      return
    }
    saveUsage()
  }

  function shortId(entry) {
    var raw = String((entry && entry.id) || "").replace(/\.desktop$/, "")
    var parts = raw.split(".")
    return normalize(parts.length ? parts[parts.length - 1] : raw)
  }

  function entrySearchText(entry) {
    var keywords = ""
    try {
      if (entry && entry.keywords && typeof entry.keywords.join === "function")
        keywords = entry.keywords.join(" ")
    } catch (e) {}
    return [entry && entry.name, entry && entry.genericName, entry && entry.comment,
            keywords, entry && entry.id].join(" ").toLowerCase()
  }

  function acronym(entry) {
    var text = [entry && entry.name, entry && entry.genericName, entry && entry.id]
      .join(" ")
      .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
      .replace(/[._:\/\\-]+/g, " ")
      .toLowerCase()
    var words = text.split(/[^a-z0-9]+/)
    var out = ""
    for (var i = 0; i < words.length; i++)
      if (words[i]) out += words[i].charAt(0)
    return out
  }

  function score(entry, rawQuery) {
    var q = String(rawQuery || "").trim().toLowerCase()
    if (!q) return 0

    var terms = q.split(/\s+/)
    var hay = entrySearchText(entry)
    var name = String((entry && entry.name) || "").toLowerCase()
    var id = String((entry && entry.id) || "").toLowerCase()
    var ac = acronym(entry)

    for (var i = 0; i < terms.length; i++) {
      var term = terms[i]
      if (!term) continue
      if (hay.indexOf(term) < 0 && ac.indexOf(term) < 0) return -1
    }

    if (name.indexOf(q) === 0) return 10000 - name.length
    if (id.indexOf(q) === 0) return 9500 - id.length
    var ni = name.indexOf(q)
    if (ni > 0) return 8000 - ni * 10 - name.length
    var hi = hay.indexOf(q)
    if (hi >= 0) return 6000 - hi
    var ai = ac.indexOf(q)
    if (ai === 0) return 5000 - ac.length
    if (ai > 0) return 4500 - ai * 10
    return 4000 - name.length
  }

  function sortedEntries(rawQuery) {
    var values = DesktopEntries.applications.values || []
    var q = String(rawQuery || "").trim()
    var result = []
    var haveRecent = false

    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || entry.noDisplay || !String(entry.name || entry.id || "")) continue
      var rank = score(entry, q)
      if (rank < 0) continue
      var used = usageCount(entry)
      if (used > 0) haveRecent = true
      result.push({
        entry: entry,
        rank: rank,
        weightedRank: rank + usageBonus(entry),
        used: used,
        name: String(entry.name || entry.id).toLowerCase()
      })
    }

    if (!q && haveRecent)
      result = result.filter(function(row) { return row.used > 0 })

    result.sort(function(a, b) {
      if (q && a.weightedRank !== b.weightedRank) return b.weightedRank - a.weightedRank
      if (!q && a.used !== b.used) return b.used - a.used
      if (a.name < b.name) return -1
      if (a.name > b.name) return 1
      return 0
    })
    return result
  }

  function matchingToplevel(entry) {
    var values = ToplevelManager.toplevels.values || []
    var target = normalize(entry && entry.id)
    var shortTarget = shortId(entry)
    var nameTarget = normalize(entry && entry.name)

    for (var i = 0; i < values.length; i++) {
      var top = values[i]
      var app = normalize(top && top.appId)
      if (!app) continue
      if (app === target || app === shortTarget || app === nameTarget ||
          (target && (app.endsWith(target) || target.endsWith(app))) ||
          (shortTarget.length > 3 && (app.endsWith(shortTarget) || shortTarget.endsWith(app))))
        return top
    }
    return null
  }

  function iconSource(entry) {
    var icon = String((entry && entry.icon) || "")
    var source = icon ? Quickshell.iconPath(icon, true) : ""
    if (!source) source = Quickshell.iconPath("application-x-executable", true)
    return source
  }

  function close() {
    open = false
    query = ""
    selectedIndex = 0
  }

  function show() {
    query = ""
    selectedIndex = 0
    open = true
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function toggle() {
    if (open) close()
    else show()
  }

  function moveSelection(delta) {
    if (!rows || rows.length === 0) return
    selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + delta))
    appList.currentIndex = selectedIndex
    appList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function activateSelected(forceNew) {
    if (!rows || rows.length === 0) return
    var idx = Math.max(0, Math.min(rows.length - 1, selectedIndex))
    var entry = rows[idx].entry
    recordUse(entry)
    close()

    if (!forceNew) {
      var existing = matchingToplevel(entry)
      if (existing) {
        existing.activate()
        return
      }
    }

    try { entry.execute() } catch (e) { console.warn("launcher execute:", e) }
  }

  onQueryChanged: {
    selectedIndex = 0
    appList.currentIndex = 0
    if (appList.count > 0) appList.positionViewAtBeginning()
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { launcher.appRevision++ }
  }

  Process {
    id: usageInitProc
    running: true
    command: ["mkdir", "-p", launcher.usageDir]
    onExited: launcher.finishUsageInit()
  }

  FileView {
    id: usageFile
    path: launcher.usagePath
    blockLoading: true
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onTextChanged: {
      if (launcher.usageReady) launcher.loadUsage()
    }
  }

  IpcHandler {
    target: "launcher"
    function toggle(): string {
      launcher.toggle()
      return launcher.open ? "open" : "closed"
    }
    function show(): string {
      launcher.show()
      return "open"
    }
    function close(): string {
      launcher.close()
      return "closed"
    }
  }

  PanelWindow {
    visible: launcher.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: ui.overlayColor
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-launcher"
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
            text: "Apps"
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
              text: "Recent apps — type to search all…"
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
              text: launcher.query
              color: colors.fgUi
              selectionColor: colors.bgHover
              selectedTextColor: colors.fgUi
              font.family: ui.sansFont
              font.pixelSize: ui.pickerInputTextSize
              selectByMouse: false
              onTextChanged: launcher.query = text

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  launcher.close()
                  event.accepted = true
                } else if (event.key === Qt.Key_Down ||
                           (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                  launcher.moveSelection(1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Up ||
                           (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                  launcher.moveSelection(-1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  launcher.activateSelected((event.modifiers & Qt.AltModifier) !== 0)
                  event.accepted = true
                }
              }
            }
          }
        }

        ListView {
          id: appList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 4
          model: launcher.rows
          currentIndex: launcher.selectedIndex

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: appList.width
            height: ui.pickerRowHeight
            radius: ui.pickerRowRadius
            color: index === launcher.selectedIndex ? colors.bgSoft : "transparent"
            border.width: index === launcher.selectedIndex ? 1 : 0
            border.color: colors.bgMuted

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 12
              spacing: 11

              Image {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                source: launcher.iconSource(modelData.entry)
                fillMode: Image.PreserveAspectFit
                smooth: true
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                  Layout.fillWidth: true
                  text: String(modelData.entry.name || modelData.entry.id || "")
                  color: colors.fgUi
                  font.family: ui.sansFont
                  font.bold: index === launcher.selectedIndex
                  font.pixelSize: ui.pickerRowTitleSize
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  visible: String(modelData.entry.genericName || modelData.entry.comment || "").length > 0
                  text: String(modelData.entry.genericName || modelData.entry.comment || "")
                  color: colors.grayDim
                  font.family: ui.sansFont
                  font.pixelSize: ui.pickerRowSubtitleSize
                  elide: Text.ElideRight
                }
              }

              Text {
                visible: launcher.matchingToplevel(modelData.entry) !== null
                text: "RUNNING"
                color: colors.green
                font.family: ui.bodyFont
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
            text: launcher.rows.length + (launcher.query.trim() ? " matches" : " recent")
            color: colors.gray
            font.family: ui.bodyFont
            font.pixelSize: ui.pickerFooterSize
          }
          Text {
            text: "↑↓ / Ctrl-JK  select   Enter  focus/open   Alt-Enter  new   Esc  close"
            color: colors.gray
            font.family: ui.bodyFont
            font.pixelSize: ui.pickerFooterSize
          }
        }
      }
    }
  }
}
