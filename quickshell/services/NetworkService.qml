import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: service

  property bool enabled: false
  property string active: ""
  property var networks: []
  readonly property bool connected: active !== ""

  function splitEscaped(line) {
    var parts = []
    var current = ""
    var escaped = false
    var text = String(line || "")
    for (var i = 0; i < text.length; i++) {
      var ch = text.charAt(i)
      if (escaped) {
        current += ch
        escaped = false
      } else if (ch === "\\") {
        escaped = true
      } else if (ch === ":") {
        parts.push(current)
        current = ""
      } else {
        current += ch
      }
    }
    parts.push(current)
    return parts
  }

  function parseSnapshot(text) {
    var section = ""
    var nextEnabled = false
    var nextActive = ""
    var nextNetworks = []
    var seen = ({})
    var lines = String(text || "").split("\n")

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line === "__WIFI__" || line === "__ACTIVE__" || line === "__NETWORKS__") {
        section = line
        continue
      }
      if (!line) continue

      if (section === "__WIFI__") {
        nextEnabled = line.toLowerCase().indexOf("enabled") >= 0
      } else if (section === "__ACTIVE__") {
        var activeParts = splitEscaped(line)
        if (activeParts.length >= 2 && (activeParts[activeParts.length - 1] === "802-11-wireless" || activeParts[activeParts.length - 1] === "wifi"))
          nextActive = activeParts.slice(0, -1).join(":")
      } else if (section === "__NETWORKS__") {
        var parts = splitEscaped(line)
        if (parts.length < 4) continue
        var ssid = parts[1]
        if (!ssid || seen[ssid]) continue
        seen[ssid] = true
        nextNetworks.push({
          ssid: ssid,
          active: parts[0] === "*",
          signal: Number(parts[2] || 0),
          security: parts.slice(3).join(":")
        })
      }
    }

    enabled = nextEnabled
    active = nextActive
    networks = nextNetworks
  }

  function refresh() {
    if (!snapshotProc.running) snapshotProc.running = true
  }

  function toggle() {
    Quickshell.execDetached(["nmcli", "radio", "wifi", enabled ? "off" : "on"])
    refreshDelay.restart()
  }

  function connectNetwork(ssid) {
    if (!ssid) return
    Quickshell.execDetached(["nmcli", "connection", "up", "id", String(ssid)])
    fallbackConnect.ssid = String(ssid)
    fallbackConnect.restart()
    refreshDelay.restart()
  }

  function openSettings() {
    Quickshell.execDetached(["kitty", "--class", "nmtui", "nmtui"])
  }

  Process {
    id: snapshotProc
    command: ["bash", "-lc",
      "printf '__WIFI__\\n'; nmcli -t -f WIFI general 2>/dev/null || true; " +
      "printf '__ACTIVE__\\n'; nmcli -t --escape yes -f NAME,TYPE connection show --active 2>/dev/null || true; " +
      "printf '__NETWORKS__\\n'; nmcli -t --escape yes -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan auto 2>/dev/null || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.parseSnapshot(text)
    }
  }

  Timer {
    id: fallbackConnect
    property string ssid: ""
    interval: 900
    onTriggered: {
      if (!ssid || service.active === ssid) return
      Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ssid])
    }
  }

  Timer {
    id: refreshDelay
    interval: 1200
    onTriggered: service.refresh()
  }

  Timer {
    interval: 15000
    repeat: true
    running: true
    onTriggered: service.refresh()
  }

  Component.onCompleted: refresh()
}
