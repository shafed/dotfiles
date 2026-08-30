import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland

Variants {
  id: bars
  required property var shell
  required property var services
  required property var system
  required property var notifications
  required property var colors
  required property var ui

  model: Quickshell.screens

  PanelWindow {
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: bars.ui.barHeight
    color: bars.colors.bgHard
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.namespace: "dots-bar"
    WlrLayershell.layer: WlrLayer.Top

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: bars.ui.barMargin
      anchors.rightMargin: bars.ui.barMargin
      spacing: bars.ui.barSpacing

      Row {
        Layout.alignment: Qt.AlignLeft
        spacing: bars.ui.barItemSpacing
        Repeater {
          model: Hyprland.workspaces
          ClickButton {
            required property var modelData
            visible: modelData.id > 0 && (modelData.focused || modelData.toplevels.values.length > 0)
            label: String(modelData.id)
            active: modelData.focused
            onPressed: modelData.activate()
          }
        }
      }

      Item { Layout.fillWidth: true }

      Row {
        Layout.alignment: Qt.AlignRight
        spacing: bars.ui.barItemSpacing

        ClickButton { label: bars.shell.layoutLabel(bars.shell.state.layout) }

        ClickButton {
          visible: bars.system.updates.count > 0
          label: "↑" + String(bars.system.updates.count)
          onPressed: bars.shell.togglePanel("updates")
        }

        ClickButton {
          visible: bars.shell.state.agents && bars.shell.state.agents.length > 0
          label: "AI"
          textColor: bars.shell.aiLimitColor()
          active: bars.shell.openPanel === "agents"
          onPressed: bars.shell.togglePanel("agents")
        }

        ClickButton {
          visible: bars.shell.laptop
          label: "BT"
          active: bars.shell.openPanel === "bluetooth"
          onPressed: bars.shell.togglePanel("bluetooth")
        }

        ClickButton {
          visible: bars.shell.laptop
          label: bars.system.network.connected ? "NET" : "NET!"
          active: bars.shell.openPanel === "network"
          onPressed: bars.shell.togglePanel("network")
        }

        ClickButton {
          label: bars.services.muted ? "MUTE" : "VOL " + String(bars.services.volume) + "%"
          active: bars.shell.openPanel === "audio"
          onPressed: bars.shell.togglePanel("audio")
        }

        ClickButton {
          visible: bars.shell.laptop
          label: "BAT " + String(bars.system.batteryPercent >= 0 ? bars.system.batteryPercent : "--") + "%"
          active: bars.shell.openPanel === "power"
          onPressed: bars.shell.togglePanel("power")
        }

        ClickButton {
          label: "CLIP"
          onPressed: {
            bars.shell.clipboardOpen = true
            bars.shell.refreshClipboard()
          }
        }

        ClickButton {
          label: bars.notifications.dnd ? "DND" : "BELL"
          active: bars.shell.openPanel === "notifications"
          onPressed: bars.shell.togglePanel("notifications")
        }

        ClickButton {
          label: Qt.formatDateTime(bars.shell.clockNow, "ddd HH:mm")
          active: bars.shell.openPanel === "calendar"
          onPressed: bars.shell.openCalendar()
        }

        Repeater {
          model: SystemTray.items
          delegate: Rectangle {
            required property var modelData
            width: bars.ui.barButtonMinWidth
            height: bars.ui.barButtonHeight
            color: trayMouse.containsMouse ? bars.colors.bgHover : "transparent"
            radius: bars.ui.barButtonRadius
            Image {
              anchors.centerIn: parent
              width: 17
              height: 17
              source: modelData.icon
              fillMode: Image.PreserveAspectFit
            }
            MouseArea {
              id: trayMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton && typeof modelData.secondaryActivate === "function")
                  modelData.secondaryActivate()
                else if (typeof modelData.activate === "function")
                  modelData.activate()
              }
            }
          }
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(bars.ui.titleMaxWidth, parent.width * bars.ui.titleWidthRatio)
      horizontalAlignment: Text.AlignHCenter
      text: ToplevelManager.activeToplevel
            ? (ToplevelManager.activeToplevel.title || ToplevelManager.activeToplevel.appId || "")
            : ""
      color: bars.colors.fgBright
      font.family: bars.ui.barFont
      font.pixelSize: bars.ui.barFontSize
      elide: Text.ElideRight
      z: 2
    }
  }
}
