import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../config" as Config

Item {
  id: service
  property var state: ({ audio: { volume: 0, muted: false } })
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property var outputs: Pipewire.nodes && Pipewire.nodes.values
                                 ? Pipewire.nodes.values.filter(function(node) {
                                     return node && node.audio && !node.isStream && node.isSink
                                   })
                                 : []
  readonly property var streams: Pipewire.nodes && Pipewire.nodes.values
                                 ? Pipewire.nodes.values.filter(function(node) {
                                     return node && node.audio && node.isStream && !node.isSink
                                   })
                                 : []
  readonly property int volume: audioSink && audioSink.ready && audioSink.audio
                                ? Math.round(audioSink.audio.volume * 100)
                                : Number(state.audio ? state.audio.volume : 0)
  readonly property bool muted: audioSink && audioSink.ready && audioSink.audio
                                ? audioSink.audio.muted
                                : !!(state.audio && state.audio.muted)
  property bool audioInitialized: false
  property int lastVolume: -1
  property bool lastMuted: false
  property string backlightPath: ""
  property int backlightMax: 0
  property int lastBrightness: -1

  signal osdRequested(string icon, string label, int value, bool hasValue)
  signal layoutChanged(string layout)

  Config.UiConfig { id: ui }

  function syncAudio() {
    if (!audioSink || !audioSink.ready || !audioSink.audio) return
    var nextVolume = Math.max(0, Math.min(150, volume))
    var nextMuted = muted
    if (!audioInitialized) {
      lastVolume = nextVolume
      lastMuted = nextMuted
      audioInitialized = true
      return
    }
    if (nextVolume !== lastVolume || nextMuted !== lastMuted)
      osdRequested(nextMuted ? "MUTE" : "VOL", String(nextVolume) + "%", nextVolume, true)
    lastVolume = nextVolume
    lastMuted = nextMuted
  }

  function adjustVolume(delta) {
    if (!audioSink || !audioSink.ready || !audioSink.audio) return
    audioSink.audio.volume = Math.max(0, Math.min(1.5, audioSink.audio.volume + delta))
  }

  function toggleMute() {
    if (!audioSink || !audioSink.ready || !audioSink.audio) return
    audioSink.audio.muted = !audioSink.audio.muted
  }

  function setDefaultOutput(node) {
    if (node) Pipewire.preferredDefaultAudioSink = node
  }

  function adjustStream(node) {
    if (!node || !node.ready || !node.audio) return
    var current = Math.round(node.audio.volume * 100)
    var next = current >= 90 ? 50 : current + 10
    node.audio.volume = Math.max(0, Math.min(1.5, next / 100.0))
  }

  function nodeLabel(node) {
    if (!node) return "Audio"
    return String(node.description || node.nickname || node.name || "Audio")
  }

  function applyLayoutSnapshot(raw) {
    var payload = null
    try { payload = JSON.parse(String(raw || "")) } catch (e) { return }
    var keyboards = payload && payload.keyboards ? payload.keyboards : []
    var fallback = ""
    for (var i = 0; i < keyboards.length; i++) {
      var keyboard = keyboards[i] || {}
      var name = String(keyboard.name || "")
      if (name.indexOf("hl-virtual-keyboard") === 0) continue
      var layout = String(keyboard.active_keymap || "")
      if (!layout) continue
      if (keyboard.main === true) {
        layoutChanged(layout)
        return
      }
      if (!fallback) fallback = layout
    }
    if (fallback) layoutChanged(fallback)
  }

  function applyLayoutEvent(event) {
    if (!event || String(event.name || "") !== "activelayout") return
    var parts = null
    try { if (event.parse) parts = event.parse(2) } catch (e) {}
    if (!parts || parts.length < 2) {
      var raw = String(event.data || "")
      var comma = raw.indexOf(",")
      if (comma >= 0) parts = [raw.slice(0, comma), raw.slice(comma + 1)]
    }
    if (!parts || parts.length < 2) return
    var keyboard = String(parts[0] || "")
    if (keyboard.indexOf("hl-virtual-keyboard") === 0) return
    var layout = String(parts[1] || "")
    if (layout) layoutChanged(layout)
  }

  function handleBrightness(value) {
    var nextValue = Number(value)
    if (isNaN(nextValue) || backlightMax <= 0) return
    var percent = Math.max(0, Math.min(100, Math.round(nextValue * 100 / backlightMax)))
    if (lastBrightness < 0) {
      lastBrightness = percent
      return
    }
    if (percent !== lastBrightness) {
      lastBrightness = percent
      osdRequested("SUN", String(percent) + "%", percent, true)
    }
  }

  PwObjectTracker {
    objects: {
      var values = service.outputs.concat(service.streams)
      if (service.audioSink && values.indexOf(service.audioSink) < 0) values.push(service.audioSink)
      return values
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { service.applyLayoutEvent(event) }
  }

  Process {
    running: true
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.applyLayoutSnapshot(text)
    }
  }

  Process {
    running: true
    command: ["bash", "-lc", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && [ -r \"$d/max_brightness\" ] && { printf '%s\\n' \"$d\"; break; }; done"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.backlightPath = text.trim()
    }
  }

  FileView {
    id: backlightMaxFile
    path: service.backlightPath ? service.backlightPath + "/max_brightness" : ""
    onTextChanged: {
      var value = Number(text().trim())
      if (!isNaN(value) && value > 0) service.backlightMax = value
    }
  }

  FileView {
    id: backlightValueFile
    path: service.backlightPath ? service.backlightPath + "/brightness" : ""
    onTextChanged: service.handleBrightness(text().trim())
  }

  Timer {
    interval: ui.brightnessPollMs
    repeat: true
    running: service.backlightPath !== ""
    onTriggered: backlightValueFile.reload()
  }

  onVolumeChanged: syncAudio()
  onMutedChanged: syncAudio()
  onAudioSinkChanged: {
    audioInitialized = false
    Qt.callLater(syncAudio)
  }
}
