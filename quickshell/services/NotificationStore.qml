import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: service

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/dots-shell"
  property alias dnd: data.dnd
  property alias history: data.history

  function add(item) {
    var next = [item]
    var previous = data.history || []
    for (var i = 0; i < previous.length && next.length < 50; i++) next.push(previous[i])
    data.history = next
  }

  function clear() {
    data.history = []
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
      property var history: []
    }
  }
}
