import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: service

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/dots-shell"
  property alias dnd: data.dnd
  property alias history: data.history
  property alias unreadCount: data.unreadCount

  function add(item) {
    var next = [item]
    var previous = data.history || []
    for (var i = 0; i < previous.length && next.length < 50; i++) next.push(previous[i])
    data.history = next
    data.unreadCount = Math.min(50, data.unreadCount + 1)
  }

  function clear() {
    data.history = []
    data.unreadCount = 0
  }

  function markRead() {
    data.unreadCount = 0
  }

  function setDnd(enabled) {
    data.dnd = !!enabled
  }

  Process {
    running: true
    command: ["mkdir", "-p", service.stateDir]
  }

  FileView {
    id: file
    path: service.stateDir + "/notifications.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: data
      property bool dnd: false
      property int unreadCount: 0
      property var history: []
    }
  }
}
