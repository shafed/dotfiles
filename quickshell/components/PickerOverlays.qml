import QtQuick
import Quickshell

Item {
  id: overlay
  required property var shell
  required property var colors
  required property var ui

  property string youtubeSelectionId: ""
  property int youtubeSelectionIndex: 0

  function clearYoutubeSelectionMemory() {
    youtubeSelectionId = ""
    youtubeSelectionIndex = 0
  }

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
    target: youtubePicker

    function onQueryChanged() {
      overlay.clearYoutubeSelectionMemory()
    }

    function onSelectedIndexChanged() {
      if (!youtubePicker.rows || youtubePicker.rows.length === 0) {
        overlay.clearYoutubeSelectionMemory()
        return
      }
      var index = Math.max(0, Math.min(youtubePicker.rows.length - 1,
                                       youtubePicker.selectedIndex))
      var row = youtubePicker.rows[index] || ({})
      overlay.youtubeSelectionId = String(row.id || "")
      overlay.youtubeSelectionIndex = index
    }

    function onRowsChanged() {
      if (!youtubePicker.rows || youtubePicker.rows.length === 0) {
        overlay.clearYoutubeSelectionMemory()
        return
      }
      if (!youtubePicker.open)
        return

      var wantedId = overlay.youtubeSelectionId
      var fallbackIndex = overlay.youtubeSelectionIndex
      if (!wantedId && fallbackIndex <= 0)
        return

      // YoutubePicker's process completion resets selectedIndex to zero after
      // assigning rows. Restore on the next event-loop turn so background
      // History/Watch Later enrichment and manual refreshes keep the user's
      // current selection. A new query/source clears the remembered selection,
      // so a genuinely new result set still starts from row zero.
      Qt.callLater(function() {
        if (!youtubePicker.open || !youtubePicker.rows || youtubePicker.rows.length === 0)
          return

        var targetIndex = -1
        if (wantedId) {
          for (var i = 0; i < youtubePicker.rows.length; i++) {
            if (String((youtubePicker.rows[i] || ({})).id || "") === wantedId) {
              targetIndex = i
              break
            }
          }
        }
        if (targetIndex < 0)
          targetIndex = Math.min(fallbackIndex, youtubePicker.rows.length - 1)
        youtubePicker.selectIndex(targetIndex)
      })
    }
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
