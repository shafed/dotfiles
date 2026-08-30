import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: service

  property int count: 0

  function refresh() {
    if (!checkProc.running) checkProc.running = true
  }

  function runUpdates() {
    Quickshell.execDetached(["kitty", "--class", "system-update", "bash", "-lc",
      "helper=; if command -v yay >/dev/null; then helper=yay; elif command -v paru >/dev/null; then helper=paru; fi; " +
      "if [ -n \"$helper\" ]; then \"$helper\" -Syu; else sudo pacman -Syu; fi; " +
      "printf '\\nPress Enter to close'; read"])
  }

  Process {
    id: checkProc
    command: ["bash", "-lc",
      "{ command -v checkupdates >/dev/null && checkupdates 2>/dev/null || true; " +
      "if command -v yay >/dev/null; then yay -Qua 2>/dev/null || true; " +
      "elif command -v paru >/dev/null; then paru -Qua 2>/dev/null || true; fi; } | sed '/^[[:space:]]*$/d'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var trimmed = text.trim()
        service.count = trimmed ? trimmed.split("\n").length : 0
      }
    }
  }

  Timer {
    interval: 600000
    repeat: true
    running: true
    onTriggered: service.refresh()
  }

  Component.onCompleted: refresh()
}
