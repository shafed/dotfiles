import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "components" as Components
import "config" as Config
import "services" as Services

ShellRoot {
  id: root

  Config.Colors { id: colors }
  Config.UiConfig { id: ui }

  readonly property string home: Quickshell.env("HOME")
  readonly property string backend: home + "/github/dotfiles/quickshell/backend.py"
  readonly property bool laptop: system.hasBattery

  property var state: ({
    audio: { volume: 0, muted: false, sinks: [], streams: [] },
    network: { enabled: false, active: "", networks: [] },
    updates: { count: 0 },
    agents: [],
    layout: ""
  })
  property string openPanel: ""
  property bool clipboardOpen: false
  property var clipboardRows: []
  property date clockNow: new Date()
  property date calendarMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
  property bool osdOpen: false
  property string osdIcon: "VOL"
  property string osdLabel: ""
  property int osdValue: 0
  property bool osdHasValue: true
  property var notificationRefs: ({})
  property bool agentsLiveRefreshed: false
  property double agentsLastUpdatedMs: 0

  Components.DesktopLauncher { id: desktopLauncher }
  Components.BookmarksPicker { id: bookmarksPicker }

  function run(args) {
    Quickshell.execDetached(args)
  }

  function layoutLabel(raw) {
    var value = String(raw || "")
    var lower = value.toLowerCase()
    if (lower.indexOf("russian") >= 0 || lower === "ru") return "RU"
    if (lower.indexOf("english") >= 0 || lower === "us" || lower === "en") return "EN"
    return value ? value.slice(0, 2).toUpperCase() : "--"
  }

  function calendarCellDate(index) {
    var first = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1)
    var mondayOffset = (first.getDay() + 6) % 7
    return new Date(first.getFullYear(), first.getMonth(), index - mondayOffset + 1)
  }

  function sameCalendarDay(a, b) {
    return a.getFullYear() === b.getFullYear() &&
           a.getMonth() === b.getMonth() &&
           a.getDate() === b.getDate()
  }

  function shiftCalendarMonth(delta) {
    calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + delta, 1)
  }

  function openCalendar() {
    if (openPanel !== "calendar") {
      var now = new Date()
      calendarMonth = new Date(now.getFullYear(), now.getMonth(), 1)
    }
    togglePanel("calendar")
  }

  function aiLimitColor() {
    var rows = state.agents || []
    var lowestRemaining = 1.0
    var found = false
    for (var i = 0; i < rows.length; i++) {
      var limits = rows[i].limits || []
      for (var j = 0; j < limits.length; j++) {
        var used = Number(limits[j].percent)
        if (isNaN(used)) continue
        found = true
        used = Math.max(0, Math.min(1, used))
        lowestRemaining = Math.min(lowestRemaining, 1 - used)
      }
    }
    if (!found) return colors.fgBright
    if (lowestRemaining <= 0.10) return colors.red
    if (lowestRemaining <= 0.30) return colors.yellow
    return colors.fgBright
  }

  function formatAgentsLastUpdated() {
    if (agentsLastUpdatedMs <= 0)
      return agentsRefreshProc.running ? "updating..." : "never"
    var nowMs = clockNow ? clockNow.getTime() : Date.now()
    var seconds = Math.max(0, Math.floor((nowMs - agentsLastUpdatedMs) / 1000))
    if (seconds < 60) return "just now"
    var minutes = Math.floor(seconds / 60)
    if (minutes < 60) return minutes + "m ago"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h ago"
    return Math.floor(hours / 24) + "d ago"
  }

  function agentTitle(agent) {
    var raw = String(agent && agent.name ? agent.name : "AI")
    var separator = raw.indexOf(" · ")
    if (separator >= 0) raw = raw.slice(0, separator)
    var plan = String(agent && agent.plan ? agent.plan : "")
    return raw + (plan ? " · " + plan : "")
  }

  function agentLimit(agent, weekly) {
    var limits = agent && agent.limits ? agent.limits : []
    for (var i = 0; i < limits.length; i++) {
      var limit = limits[i]
      var label = String(limit && limit.label ? limit.label : "").toLowerCase()
      if (weekly && label === "7d") return limit
      if (!weekly && label !== "7d") return limit
    }
    return null
  }

  function limitUsed(limit) {
    if (!limit) return 0
    var value = Number(limit.percent)
    if (isNaN(value)) return 0
    return Math.max(0, Math.min(1, value))
  }

  function limitColor(limit) {
    if (!limit) return colors.grayDim
    var remaining = 1 - limitUsed(limit)
    if (remaining <= 0.10) return colors.red
    if (remaining <= 0.30) return colors.yellow
    return colors.green
  }

  function formatLimitReset(raw) {
    if (raw === undefined || raw === null || String(raw) === "") return "Reset time unavailable"
    var numeric = Number(raw)
    var when = !isNaN(numeric) && numeric > 0
               ? new Date(numeric < 100000000000 ? numeric * 1000 : numeric)
               : new Date(String(raw))
    if (isNaN(when.getTime())) return "Reset time unavailable"

    var now = new Date()
    var delta = when.getTime() - now.getTime()
    if (delta > 0 && delta <= 24 * 60 * 60 * 1000) {
      var totalMinutes = Math.max(1, Math.ceil(delta / 60000))
      var hours = Math.floor(totalMinutes / 60)
      var minutes = totalMinutes % 60
      if (hours > 0) return "Resets in " + hours + "h " + minutes + "m"
      return "Resets in " + minutes + "m"
    }
    return "Resets " + Qt.formatDateTime(when, "ddd HH:mm")
  }

  function backendAction(domain, action, arg) {
    var argv = ["python3", backend, "action", domain, action]
    if (arg !== undefined && arg !== null && String(arg) !== "") argv.push(String(arg))
    run(argv)
    fullRefreshDelay.restart()
  }

  function togglePanel(name) {
    if (!laptop && (name === "network" || name === "bluetooth")) return
    desktopLauncher.close()
    bookmarksPicker.close()
    clipboardOpen = false
    openPanel = openPanel === name ? "" : name
    if (openPanel !== "" && !fullProc.running) fullProc.running = true
  }

  function updateFull(next) {
    if (state.layout) next.layout = state.layout
    if (agentsLiveRefreshed && state.agents) next.agents = state.agents
    state = next
  }

  function updateLayout(layout) {
    var merged = state
    merged.layout = layout
    state = Object.assign({}, merged)
  }

  function refreshClipboard() {
    if (!clipboardProc.running) clipboardProc.running = true
  }

  function showOsd(icon, label, value, hasValue) {
    osdIcon = icon
    osdLabel = label
    osdValue = Number(value || 0)
    osdHasValue = hasValue !== false
    osdOpen = true
    osdTimer.restart()
  }

  function hydrateNotifications() {
    historyModel.clear()
    var rows = notifications.history || []
    for (var i = 0; i < rows.length; i++) historyModel.append(rows[i])
  }

  function receiveNotification(notification) {
    notification.tracked = true
    var stamp = Date.now()
    var item = {
      id: Number(notification.id || stamp),
      app: String(notification.appName || ""),
      summary: String(notification.summary || ""),
      body: String(notification.body || ""),
      timestamp: stamp
    }
    notifications.add(item)

    if (notifications.dnd) {
      notification.tracked = false
      return
    }

    notificationRefs[String(item.id)] = notification
    toastModel.insert(0, item)
    while (toastModel.count > 4) releaseToast(toastModel.count - 1, true)
    toastTimer.restart()
  }

  function releaseToast(index, expired) {
    if (index < 0 || index >= toastModel.count) return
    var row = toastModel.get(index)
    var ref = notificationRefs[String(row.id)]
    toastModel.remove(index)
    if (ref) {
      try {
        if (expired && typeof ref.expire === "function") ref.expire()
        else if (typeof ref.dismiss === "function") ref.dismiss()
        else ref.tracked = false
      } catch (e) {}
      delete notificationRefs[String(row.id)]
    }
  }

  Component.onCompleted: {
    run(["pkill", "-x", "waybar"])
    hydrateNotifications()
    fullProc.running = true
  }

  Services.DesktopServices {
    id: desktop
    state: root.state
    onOsdRequested: (icon, label, value, hasValue) => root.showOsd(icon, label, value, hasValue)
    onLayoutChanged: layout => root.updateLayout(layout)
  }

  Services.SystemServices { id: system }
  Services.NotificationStore { id: notifications }

  Connections {
    target: notifications
    function onHistoryChanged() { root.hydrateNotifications() }
  }

  ListModel { id: historyModel }
  ListModel { id: toastModel }

  Process {
    id: fullProc
    command: ["python3", root.backend, "snapshot"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.updateFull(JSON.parse(text)) } catch (e) { console.warn("dots-shell full snapshot:", e) }
      }
    }
  }

  Process {
    id: clipboardProc
    command: ["python3", root.backend, "clipboard-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.clipboardRows = JSON.parse(text) } catch (e) { root.clipboardRows = [] }
      }
    }
  }

  Process {
    running: true
    command: ["bash", "-lc", "for i in $(seq 1 20); do pkill -x waybar >/dev/null 2>&1 || true; sleep 0.5; done"]
  }

  Process {
    running: true
    command: ["bash", "-lc",
      "if command -v cliphist >/dev/null && command -v wl-paste >/dev/null; then exec wl-paste --type text --watch cliphist store; else exec sleep infinity; fi"]
  }

  Process {
    id: agentsRefreshProc
    running: true
    command: ["python3", root.home + "/github/dotfiles/quickshell/agents-refresh.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var rows = JSON.parse(text)
          var merged = root.state
          merged.agents = rows
          root.state = Object.assign({}, merged)
          root.agentsLiveRefreshed = true
          root.agentsLastUpdatedMs = Date.now()
        } catch (e) {
          console.warn("dots-shell agents refresh:", e)
        }
      }
    }
  }

  Timer {
    interval: ui.fullRefreshMs
    repeat: true
    running: true
    onTriggered: if (!fullProc.running) fullProc.running = true
  }

  Timer {
    id: fullRefreshDelay
    interval: 900
    onTriggered: if (!fullProc.running) fullProc.running = true
  }

  Timer {
    interval: ui.clockRefreshMs
    repeat: true
    running: true
    onTriggered: root.clockNow = new Date()
  }

  Timer {
    id: osdTimer
    interval: ui.osdTimeoutMs
    onTriggered: root.osdOpen = false
  }

  Timer {
    id: toastTimer
    interval: ui.toastTimeoutMs
    onTriggered: {
      if (toastModel.count > 0) root.releaseToast(toastModel.count - 1, true)
      if (toastModel.count > 0) restart()
    }
  }

  NotificationServer {
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    bodyMarkupSupported: true
    onNotification: notification => root.receiveNotification(notification)
  }

  IpcHandler {
    target: "dots"
    function closeOverlays(): string {
      root.openPanel = ""
      root.clipboardOpen = false
      return "ok"
    }
    function toggleClipboard(): string {
      desktopLauncher.close()
      bookmarksPicker.close()
      root.openPanel = ""
      root.clipboardOpen = !root.clipboardOpen
      if (root.clipboardOpen) root.refreshClipboard()
      return root.clipboardOpen ? "open" : "closed"
    }
    function panel(name: string): string {
      root.togglePanel(name)
      return root.openPanel
    }
    function refresh(): string {
      if (!root.fullProc.running) root.fullProc.running = true
      return "ok"
    }
    function showOsd(icon: string, label: string, value: string): string {
      root.showOsd(icon, label, Number(value), true)
      return "ok"
    }
  }

  Components.TopBar {
    shell: root
    services: desktop
    system: system
    notifications: notifications
    colors: colors
    ui: ui
  }

  Components.SystemPanel {
    shell: root
    services: desktop
    system: system
    notifications: notifications
    colors: colors
    ui: ui
    historyModel: historyModel
    agentsRefreshProc: agentsRefreshProc
  }

  Components.ClipboardOverlay { shell: root; colors: colors; ui: ui }
  Components.ToastOverlay { shell: root; colors: colors; ui: ui; toastModel: toastModel }
  Components.OsdOverlay { shell: root; colors: colors; ui: ui }
}
