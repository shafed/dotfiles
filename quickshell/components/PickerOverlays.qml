import QtQuick
import Quickshell

Item {
  id: overlay
  required property var shell
  required property var colors
  required property var ui

  QuickPicker {
    id: quickPicker
    shell: overlay.shell
    colors: overlay.colors
    ui: overlay.ui
  }

  YoutubePicker {
    id: youtubePicker
    shell: overlay.shell
    colors: overlay.colors
    ui: overlay.ui
  }

  ScratchOverlay {
    id: scratchOverlay
    shell: overlay.shell
    colors: overlay.colors
    ui: overlay.ui
  }

  Connections {
    target: overlay.shell

    function onOpenPanelChanged() {
      if (overlay.shell.openPanel !== "") {
        quickPicker.close()
        youtubePicker.close()
        scratchOverlay.close()
      }
    }
  }
}
