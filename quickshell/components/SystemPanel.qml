import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
  id: panel
  required property var shell
  required property var services
  required property var colors
  required property var ui
  required property var historyModel
  required property var agentsRefreshProc
PanelWindow {
  visible: panel.shell.openPanel !== ""
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dots-panel"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  onVisibleChanged: {
    if (visible) Qt.callLater(function() { panelCard.forceActiveFocus() })
  }

  MouseArea {
    anchors.fill: parent
    onClicked: panel.shell.openPanel = ""
  }

  Rectangle {
    id: panelCard
    width: Math.min(panel.ui.panelWidth, parent.width - 2 * panel.ui.panelRightMargin)
    height: Math.min(panel.ui.panelHeight, parent.height - panel.ui.panelTopMargin - panel.ui.panelOuterGap)
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: panel.ui.panelTopMargin
    anchors.rightMargin: panel.ui.panelRightMargin
    focus: panel.shell.openPanel !== ""
    Keys.onEscapePressed: panel.shell.openPanel = ""
    color: panel.colors.bgHard
    border.color: panel.colors.bgHover
    border.width: 1
    radius: panel.ui.panelRadius

    MouseArea { anchors.fill: parent }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: panel.ui.panelPadding
      spacing: panel.ui.panelSpacing

      RowLayout {
        Layout.fillWidth: true
        Text {
          Layout.fillWidth: true
          text: panel.shell.openPanel.toUpperCase()
          color: panel.colors.yellow
          font.family: panel.ui.bodyFont
          font.bold: true
          font.pixelSize: 14
        }
        ClickButton { label: "×"; onPressed: panel.shell.openPanel = "" }
      }

      Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        sourceComponent: panel.shell.openPanel === "audio" ? audioPanel :
                         panel.shell.openPanel === "network" ? networkPanel :
                         panel.shell.openPanel === "bluetooth" ? bluetoothPanel :
                         panel.shell.openPanel === "power" ? powerPanel :
                         panel.shell.openPanel === "calendar" ? calendarPanel :
                         panel.shell.openPanel === "agents" ? agentsPanel :
                         panel.shell.openPanel === "updates" ? updatesPanel :
                         panel.shell.openPanel === "notifications" ? notificationsPanel : null
      }
    }
  }
}

Component { id: audioPanel; AudioPanel { shell: panel.shell; services: panel.services; colors: panel.colors; ui: panel.ui } }
Component { id: networkPanel; NetworkPanel { shell: panel.shell; colors: panel.colors; ui: panel.ui } }
Component { id: bluetoothPanel; BluetoothPanel { shell: panel.shell; colors: panel.colors; ui: panel.ui } }
Component { id: calendarPanel; CalendarPanel { shell: panel.shell; colors: panel.colors; ui: panel.ui } }
Component { id: powerPanel; PowerPanel { shell: panel.shell; colors: panel.colors; ui: panel.ui } }
Component { id: agentsPanel; AgentsPanel { shell: panel.shell; colors: panel.colors; ui: panel.ui; agentsRefreshProc: panel.agentsRefreshProc } }
Component { id: updatesPanel; UpdatesPanel { shell: panel.shell; colors: panel.colors; ui: panel.ui } }
Component { id: notificationsPanel; NotificationsPanel { shell: panel.shell; colors: panel.colors; ui: panel.ui; historyModel: panel.historyModel } }
}
