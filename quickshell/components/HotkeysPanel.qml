import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: hotkeys

  required property var shell
  required property var colors
  required property var ui

  property bool open: false
  property string query: ""

  // Curated presentation index only. Canonical bindings stay in
  // hypr/hyprland.lua, kanata/config.kbd and kitty/kitty.conf.
  readonly property var sections: [
    {
      title: "Hyprland · shell & system",
      accent: "yellow",
      entries: [
        { key: "Super + F1", action: "Toggle this hotkey panel" },
        { key: "Super + Space", action: "Applications" },
        { key: "Super + V", action: "Clipboard" },
        { key: "Super + Shift + A", action: "Audio panel" },
        { key: "Super + Shift + W", action: "Network panel" },
        { key: "Super + Shift + B", action: "Bluetooth panel" },
        { key: "Super + Shift + P", action: "Power panel" },
        { key: "Super + Shift + I", action: "AI agents panel" },
        { key: "Super + Shift + U", action: "Updates panel" },
        { key: "Super + Shift + N", action: "Notifications panel" },
        { key: "Super + Home", action: "Suspend and lock" },
        { key: "Super + N", action: "Toggle Neovim scratch note" },
        { key: "Super + .", action: "Toggle Handy" },
        { key: "Ctrl + Super_L", action: "Toggle OpenWhispr" },
        { key: "XF86 media keys", action: "Volume, mic, brightness and playback" }
      ]
    },
    {
      title: "Hyprland · windows & workspaces",
      accent: "yellow",
      entries: [
        { key: "Super + Enter", action: "New Kitty OS window" },
        { key: "Super + E", action: "File manager" },
        { key: "Super + Y", action: "Toggle floating" },
        { key: "Super + F", action: "Toggle fullscreen" },
        { key: "Super + P", action: "Toggle pseudo-tiling" },
        { key: "Super + H/J/K/L", action: "Move focus" },
        { key: "Super + Alt + H/J/K/L", action: "Swap window" },
        { key: "Super + Ctrl + H/J/K/L", action: "Resize window" },
        { key: "Super + 1…0", action: "Switch workspace 1…10" },
        { key: "Super + Shift + 1…0", action: "Move window to workspace 1…10" },
        { key: "Super + S", action: "Toggle special workspace" },
        { key: "Super + Shift + S", action: "Move window to special workspace" },
        { key: "Super + wheel", action: "Previous / next workspace" },
        { key: "Super + LMB / RMB", action: "Drag / resize window" },
        { key: "Super + F5", action: "Exit Hyprland" }
      ]
    },
    {
      title: "Kanata · base",
      accent: "green",
      entries: [
        { key: "hold A/S/D/F", action: "Alt / Super / Ctrl / Shift" },
        { key: "hold J/K/L", action: "Shift / Ctrl / Super" },
        { key: "LAlt tap / hold", action: "Backspace / Apps layer" },
        { key: "RAlt tap / hold", action: "Switch language / Apps layer" },
        { key: "hold C / V", action: "Copy / paste" },
        { key: "hold B", action: "Previous Kitty session" },
        { key: "hold X", action: "Previous window" },
        { key: "hold Z", action: "Previous workspace" },
        { key: "hold M / N", action: "Workspace switch / move layers" },
        { key: "hold W", action: "Navigation layer" },
        { key: "hold Caps", action: "Toggle navigation layer" },
        { key: "hold Enter", action: "Normal layer" }
      ]
    },
    {
      title: "Kanata · Apps layer",
      accent: "green",
      entries: [
        { key: "Apps + A", action: "Applications" },
        { key: "Apps + B", action: "Bookmarks" },
        { key: "Apps + C", action: "Kitty session picker" },
        { key: "Apps + D", action: "Dotfiles Kitty session" },
        { key: "Apps + E", action: "Zoxide Kitty session picker" },
        { key: "Apps + G", action: "GitHub Kitty session" },
        { key: "Apps + H", action: "Home Kitty session" },
        { key: "Apps + L", action: "Workspace-number layer" },
        { key: "Apps + O", action: "Obsidian Kitty session" },
        { key: "Apps + Q", action: "Close current app/window" },
        { key: "Apps + R", action: "Daily note" },
        { key: "Apps + S tap / hold", action: "Open Helium / browser layer" },
        { key: "Apps + T", action: "Todos Kitty session" },
        { key: "Apps + U", action: "YouTube search" },
        { key: "Apps + W", action: "Downloads Kitty session" },
        { key: "Apps + Y", action: "YouTube Watch Later" },
        { key: "Apps + Z", action: "Sioyek" },
        { key: "Apps + .", action: "Emoji picker" },
        { key: "Apps + W+E", action: "System overview · entry point" },
        { key: "Apps + E+R", action: "AI limits · software zone" },
        { key: "Apps + R+T", action: "Updates · software zone" },
        { key: "Apps + Y+U", action: "Audio panel · sound zone" },
        { key: "Apps + U+I", action: "Volume down · sound zone" },
        { key: "Apps + I+O", action: "Volume up · sound zone" },
        { key: "Apps + O+P", action: "Mute output · sound zone" },
        { key: "Apps + H+J", action: "Network / Wi-Fi · hardware zone" },
        { key: "Apps + J+K", action: "Brightness down · hardware zone" },
        { key: "Apps + K+L", action: "Brightness up · hardware zone" },
        { key: "Apps + L+;", action: "Bluetooth · hardware zone" },
        { key: "Apps + D+F", action: "Notifications · utility zone" },
        { key: "Apps + X+C", action: "Calendar · utility zone" },
        { key: "Apps + C+V", action: "Power · utility zone" }
      ]
    },
    {
      title: "Kanata · chords & navigation",
      accent: "green",
      entries: [
        { key: "D + F (outside Apps)", action: "Esc / hold Ctrl+Shift" },
        { key: "J + K (outside Apps)", action: "Enter / hold Ctrl+Shift" },
        { key: "S + F", action: "Super + Shift" },
        { key: "K + L (outside Apps)", action: "Number layer" },
        { key: "J + K + L", action: "Shifted-number layer" },
        { key: "S + D", action: "Symbols layer" },
        { key: "S + D + F", action: "Symbols layer 2" },
        { key: "J + L", action: "Move-window workspace layer" },
        { key: "W + E (outside Apps)", action: "Tab" },
        { key: "both Shift keys", action: "Return to base layer" },
        { key: "Navi H/J/K/L", action: "Left / down / up / right" },
        { key: "Navi N/M", action: "Previous / next word" },
        { key: "Navi U/I", action: "Previous / next browser tab" },
        { key: "Navi O/P", action: "Browser back / forward" },
        { key: "Navi [ / ]", action: "Home / End" },
        { key: "Browser E/F/G/D/R", action: "Gmail / Perplexity / ChatGPT / Claude / Reverso" }
      ]
    },
    {
      title: "Kitty · sessions & terminal",
      accent: "aqua",
      entries: [
        { key: "Ctrl + Shift + A", action: "Home session" },
        { key: "Ctrl + Shift + 2", action: "Todos session" },
        { key: "Ctrl + Shift + W", action: "Downloads session" },
        { key: "Ctrl + Shift + O", action: "Obsidian session" },
        { key: "Ctrl + Shift + C", action: "GitHub session" },
        { key: "Ctrl + Shift + D", action: "Dotfiles session" },
        { key: "Alt + Tab", action: "Previous session" },
        { key: "Ctrl + Shift + 1", action: "Daily notes overlay" },
        { key: "Ctrl + Shift + T", action: "New tab in current directory" },
        { key: "Ctrl + Shift + Enter", action: "Vertical split in current directory" },
        { key: "Ctrl + Shift + X", action: "Close Kitty window/split" },
        { key: "Ctrl + Shift + I", action: "Scrollback in Neovim" },
        { key: "Ctrl + H/J/K/L", action: "Context-aware split/window navigation" },
        { key: "Ctrl + Backspace", action: "Delete previous word" }
      ]
    }
  ]

  function accentColor(name) {
    if (name === "green") return colors.green
    if (name === "aqua") return colors.aqua
    return colors.yellow
  }

  function filteredEntries(entries) {
    var q = query.trim().toLowerCase()
    if (!q) return entries
    var out = []
    for (var i = 0; i < entries.length; i++) {
      var row = entries[i]
      var haystack = (String(row.key) + " " + String(row.action)).toLowerCase()
      if (haystack.indexOf(q) >= 0) out.push(row)
    }
    return out
  }

  function close() {
    open = false
    query = ""
  }

  function show() {
    shell.openPanel = ""
    query = ""
    open = true
    Qt.callLater(function() { searchInput.forceActiveFocus() })
  }

  function toggle() {
    if (open) close()
    else show()
  }

  IpcHandler {
    target: "hotkeys"
    function toggle(): string {
      hotkeys.toggle()
      return hotkeys.open ? "open" : "closed"
    }
    function show(): string {
      hotkeys.show()
      return "open"
    }
    function close(): string {
      hotkeys.close()
      return "closed"
    }
  }

  PanelWindow {
    id: hotkeysWindow
    visible: hotkeys.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: hotkeys.ui.overlayColor
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-hotkeys"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: if (visible) Qt.callLater(function() { searchInput.forceActiveFocus() })

    MouseArea {
      anchors.fill: parent
      onClicked: hotkeys.close()
    }

    Rectangle {
      id: card
      width: Math.min(hotkeys.ui.pickerMaxWidth + 260, parent.width - 64)
      height: Math.min(hotkeys.ui.pickerMaxHeight + 160, parent.height - 64)
      anchors.centerIn: parent
      color: hotkeys.colors.bgHard
      border.color: hotkeys.colors.bgHover
      border.width: 1
      radius: hotkeys.ui.pickerRadius
      focus: hotkeys.open
      Keys.onEscapePressed: hotkeys.close()

      MouseArea { anchors.fill: parent }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: hotkeys.ui.pickerPadding + 2
        spacing: hotkeys.ui.pickerSpacing + 2

        RowLayout {
          Layout.fillWidth: true
          spacing: hotkeys.ui.pickerSpacing + 2

          Text {
            text: "Hotkeys"
            color: hotkeys.colors.yellow
            font.family: hotkeys.ui.bodyFont
            font.bold: true
            font.pixelSize: hotkeys.ui.pickerTitleSize + 2
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: hotkeys.ui.pickerInputHeight
            radius: hotkeys.ui.pickerInputRadius
            color: hotkeys.colors.bg
            border.color: searchInput.activeFocus ? hotkeys.colors.yellow : hotkeys.colors.bgHover
            border.width: 1

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: searchInput.text.length === 0
              text: "Filter keys or actions…"
              color: hotkeys.colors.gray
              font.family: hotkeys.ui.sansFont
              font.pixelSize: hotkeys.ui.pickerHintSize
            }

            TextInput {
              id: searchInput
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              text: hotkeys.query
              color: hotkeys.colors.fgUi
              selectionColor: hotkeys.colors.bgHover
              selectedTextColor: hotkeys.colors.fgUi
              font.family: hotkeys.ui.sansFont
              font.pixelSize: hotkeys.ui.pickerInputTextSize
              onTextChanged: hotkeys.query = text
              Keys.onEscapePressed: hotkeys.close()
            }
          }
        }

        Flickable {
          id: flick
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentWidth: width
          contentHeight: contents.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: contents
            width: flick.width
            spacing: 16

            Repeater {
              model: hotkeys.sections

              delegate: Column {
                id: section
                required property var modelData
                property var rows: hotkeys.filteredEntries(modelData.entries)
                width: contents.width
                spacing: 6
                visible: rows.length > 0

                Text {
                  width: parent.width
                  text: section.modelData.title
                  color: hotkeys.accentColor(section.modelData.accent)
                  font.family: hotkeys.ui.bodyFont
                  font.bold: true
                  font.pixelSize: hotkeys.ui.panelButtonTextSize
                }

                Repeater {
                  model: section.rows

                  delegate: Rectangle {
                    required property var modelData
                    width: section.width
                    height: 34
                    radius: hotkeys.ui.panelButtonRadius
                    color: hotkeys.colors.bg

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: 10
                      anchors.rightMargin: 10
                      spacing: 14

                      Text {
                        Layout.preferredWidth: 280
                        text: modelData.key
                        color: hotkeys.colors.fgUi
                        font.family: hotkeys.ui.bodyFont
                        font.pixelSize: hotkeys.ui.pickerRowSubtitleSize
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Text {
                        Layout.fillWidth: true
                        text: modelData.action
                        color: hotkeys.colors.grayDim
                        font.family: hotkeys.ui.sansFont
                        font.pixelSize: hotkeys.ui.pickerRowSubtitleSize
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Text {
          Layout.alignment: Qt.AlignRight
          text: "type to filter   ·   Esc / Super+F1 close"
          color: hotkeys.colors.gray
          font.family: hotkeys.ui.bodyFont
          font.pixelSize: hotkeys.ui.pickerFooterSize
        }
      }
    }
  }
}
