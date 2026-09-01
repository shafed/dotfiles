import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: service

  property var events: []
  property string setupState: "loading"
  property string error: ""
  property bool refreshing: false
  property bool refreshPending: false
  property bool syncing: false
  property double lastUpdatedMs: 0
  property string rangeStart: ""
  property int rangeDays: 42

  readonly property bool configured: setupState === "ready"

  function pad2(value) {
    return String(value).padStart(2, "0")
  }

  function dateText(date) {
    return String(date.getFullYear()) + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
  }

  function gridStartForMonth(monthDate) {
    var first = new Date(monthDate.getFullYear(), monthDate.getMonth(), 1)
    var mondayOffset = (first.getDay() + 6) % 7
    return new Date(first.getFullYear(), first.getMonth(), 1 - mondayOffset)
  }

  function loadMonth(monthDate) {
    rangeStart = dateText(gridStartForMonth(monthDate || new Date()))
    rangeDays = 42
    refresh()
  }

  function parseLocalDate(dateTextValue, timeText, allDay) {
    var dateParts = String(dateTextValue || "").split("-")
    if (dateParts.length !== 3) return null
    var hour = 0
    var minute = 0
    if (!allDay) {
      var timeParts = String(timeText || "").split(":")
      if (timeParts.length < 2) return null
      hour = Number(timeParts[0])
      minute = Number(timeParts[1])
    }
    return new Date(Number(dateParts[0]), Number(dateParts[1]) - 1, Number(dateParts[2]), hour, minute, 0, 0)
  }

  function normalizeEvent(row) {
    var allDay = String(row["all-day"] || "").toLowerCase() === "true"
    var startDate = String(row["start-date"] || "")
    var endDate = String(row["end-date"] || startDate)
    var startTime = String(row["start-time"] || "")
    var endTime = String(row["end-time"] || "")
    var start = parseLocalDate(startDate, startTime, allDay)
    var end = parseLocalDate(endDate, endTime, allDay)
    if (!start || isNaN(start.getTime())) return null
    if (!end || isNaN(end.getTime()) || end.getTime() <= start.getTime())
      end = new Date(start.getTime() + (allDay ? 86400000 : 3600000))

    return {
      title: String(row.title || "Untitled"),
      location: String(row.location || ""),
      calendar: String(row.calendar || ""),
      allDay: allDay,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      startMs: start.getTime(),
      endMs: end.getTime()
    }
  }

  function parseKhalRows(raw) {
    var value = String(raw || "").trim()
    if (!value) return []

    var parsed = []
    var lines = value.split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var chunk = JSON.parse(line)
      if (Array.isArray(chunk)) {
        for (var j = 0; j < chunk.length; j++) parsed.push(chunk[j])
      } else if (chunk && typeof chunk === "object") {
        parsed.push(chunk)
      }
    }
    return parsed
  }

  function loadEvents(raw) {
    var parsed = parseKhalRows(raw)
    var rows = []
    for (var i = 0; i < parsed.length; i++) {
      var item = normalizeEvent(parsed[i])
      if (item) rows.push(item)
    }
    rows.sort(function(a, b) { return a.startMs - b.startMs })
    events = rows
    setupState = "ready"
    error = ""
    lastUpdatedMs = Date.now()
  }

  function refresh() {
    if (queryProc.running) {
      refreshPending = true
      return
    }
    refreshing = true
    queryProc.running = true
  }

  function sync() {
    if (syncProc.running) return
    syncing = true
    syncProc.running = true
  }

  function sameDay(date, ms) {
    var other = new Date(ms)
    return date.getFullYear() === other.getFullYear() &&
           date.getMonth() === other.getMonth() &&
           date.getDate() === other.getDate()
  }

  function eventTouchesDay(event, date) {
    var dayStart = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
    var dayEnd = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime()
    return event.startMs < dayEnd && event.endMs > dayStart
  }

  function hasEventsOn(date) {
    for (var i = 0; i < events.length; i++) {
      if (eventTouchesDay(events[i], date)) return true
    }
    return false
  }

  function eventsOn(date) {
    var rows = []
    for (var i = 0; i < events.length; i++) {
      if (eventTouchesDay(events[i], date)) rows.push(events[i])
    }
    return rows
  }

  function timeLabel(event) {
    if (event.allDay) return "all day"
    if (event.endTime) return event.startTime + "–" + event.endTime
    return event.startTime
  }

  Process {
    id: queryProc
    command: ["bash", "-lc",
      "state=\"${XDG_STATE_HOME:-$HOME/.local/state}\"; " +
      "client_id=\"$state/dotfiles/secrets/google-calendar/client-id\"; " +
      "client_secret=\"$state/dotfiles/secrets/google-calendar/client-secret\"; " +
      "token=\"$HOME/.local/state/vdirsyncer/google-token\"; " +
      "if [ ! -s \"$client_id\" ] || [ ! -s \"$client_secret\" ]; then printf '__DOTS_CALENDAR_CREDENTIALS__'; " +
      "elif [ ! -s \"$token\" ]; then printf '__DOTS_CALENDAR_DISCOVER__'; " +
      "elif ! command -v khal >/dev/null 2>&1; then printf '__DOTS_CALENDAR_ERROR__:khal missing'; " +
      "elif output=$(khal list --once --json title --json start-date --json start-time --json end-date --json end-time --json all-day --json location --json calendar " + service.rangeStart + " " + String(service.rangeDays) + "d 2>/dev/null); then printf '%s' \"$output\"; " +
      "else printf '__DOTS_CALENDAR_ERROR__:khal query failed'; fi"]
    onExited: function(exitCode, exitStatus) {
      service.refreshing = false
      if (service.refreshPending) {
        service.refreshPending = false
        service.refresh()
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = text.trim()
        if (value === "__DOTS_CALENDAR_CREDENTIALS__") {
          service.events = []
          service.setupState = "credentials"
          service.error = ""
          return
        }
        if (value === "__DOTS_CALENDAR_DISCOVER__") {
          service.events = []
          service.setupState = "discover"
          service.error = ""
          return
        }
        if (value.indexOf("__DOTS_CALENDAR_ERROR__:") === 0) {
          service.setupState = "error"
          service.error = value.slice("__DOTS_CALENDAR_ERROR__:".length)
          return
        }
        try {
          service.loadEvents(value)
        } catch (e) {
          service.events = []
          service.setupState = "error"
          service.error = "invalid khal output"
        }
      }
    }
  }

  Process {
    id: syncProc
    command: ["systemctl", "--user", "start", "google-calendar-sync.service"]
    onExited: function(exitCode, exitStatus) {
      service.syncing = false
      if (exitCode !== 0) {
        service.error = "calendar sync failed"
        service.setupState = "error"
      }
      refreshAfterSync.restart()
    }
  }

  Timer {
    id: refreshAfterSync
    interval: 300
    onTriggered: service.refresh()
  }

  Timer {
    interval: 120000
    repeat: true
    running: true
    onTriggered: service.refresh()
  }

  Component.onCompleted: loadMonth(new Date())
}
