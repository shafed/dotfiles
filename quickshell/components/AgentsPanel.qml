import QtQuick
import QtQuick.Layouts
import Quickshell

Flickable {
  id: view
  required property var shell
  required property var agents
  required property var colors
  required property var ui

  contentWidth: width
  contentHeight: agentsColumn.implicitHeight
  clip: true
  Component.onCompleted: view.agents.refresh()
  ColumnLayout {
    id: agentsColumn
    width: parent.width
    spacing: 10
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        Layout.fillWidth: true
        text: "Last updated: " + view.shell.formatAgentsLastUpdated()
        color: view.colors.grayDim
        font.family: view.ui.bodyFont
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
      }

      Rectangle {
        Layout.preferredWidth: view.ui.barButtonMinWidth
        Layout.preferredHeight: view.ui.barButtonHeight
        radius: view.ui.barButtonRadius
        color: refreshMouse.containsMouse ? view.colors.bgHover : "transparent"
        opacity: view.agents.refreshing ? 0.55 : 1.0

        Text {
          id: refreshIcon
          anchors.centerIn: parent
          text: "↻"
          color: view.colors.fgSoft
          font.family: view.ui.barFont
          font.pixelSize: 17

          RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
            running: view.agents.refreshing
          }
        }

        MouseArea {
          id: refreshMouse
          anchors.fill: parent
          hoverEnabled: true
          enabled: !view.agents.refreshing
          cursorShape: Qt.PointingHandCursor
          onClicked: view.agents.refresh()
        }
      }
    }
    Repeater {
      model: view.shell.state.agents || []
      Rectangle {
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: agentColumn.implicitHeight + 20
        radius: 6
        color: view.colors.bg
        border.color: view.colors.bgHover
        ColumnLayout {
          id: agentColumn
          property var currentLimit: view.shell.agentLimit(modelData, false)
          property var weeklyLimit: view.shell.agentLimit(modelData, true)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 10
          spacing: 10
          RowLayout {
            Layout.fillWidth: true
            Heading { Layout.fillWidth: true; text: view.shell.agentTitle(modelData) }
            Text {
              visible: !!modelData.stale
              text: "cached"
              color: view.colors.yellow
              font.family: view.ui.bodyFont
              font.pixelSize: 10
            }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
              Layout.fillWidth: true
              Text { Layout.fillWidth: true; text: "Current session"; color: view.colors.fgSoft; font.family: view.ui.bodyFont; font.pixelSize: 12 }
              Text {
                text: agentColumn.currentLimit ? Math.round(view.shell.limitUsed(agentColumn.currentLimit) * 100) + "% used" : "Unavailable"
                color: view.shell.limitColor(agentColumn.currentLimit)
                font.family: view.ui.bodyFont
                font.pixelSize: 12
              }
            }
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 7
              radius: 4
              color: view.colors.bgSoft
              Rectangle {
                width: parent.width * view.shell.limitUsed(agentColumn.currentLimit)
                height: parent.height
                radius: parent.radius
                color: view.shell.limitColor(agentColumn.currentLimit)
              }
            }
            Text {
              text: agentColumn.currentLimit ? view.shell.formatLimitReset(agentColumn.currentLimit.resetsAt) : "Reset time unavailable"
              color: view.colors.grayDim
              font.family: view.ui.bodyFont
              font.pixelSize: 11
            }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
              Layout.fillWidth: true
              Text { Layout.fillWidth: true; text: "Weekly limits"; color: view.colors.fgSoft; font.family: view.ui.bodyFont; font.pixelSize: 12 }
              Text {
                text: agentColumn.weeklyLimit ? Math.round(view.shell.limitUsed(agentColumn.weeklyLimit) * 100) + "% used" : "Unavailable"
                color: view.shell.limitColor(agentColumn.weeklyLimit)
                font.family: view.ui.bodyFont
                font.pixelSize: 12
              }
            }
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: 7
              radius: 4
              color: view.colors.bgSoft
              Rectangle {
                width: parent.width * view.shell.limitUsed(agentColumn.weeklyLimit)
                height: parent.height
                radius: parent.radius
                color: view.shell.limitColor(agentColumn.weeklyLimit)
              }
            }
            Text {
              text: agentColumn.weeklyLimit ? view.shell.formatLimitReset(agentColumn.weeklyLimit.resetsAt) : "Reset time unavailable"
              color: view.colors.grayDim
              font.family: view.ui.bodyFont
              font.pixelSize: 11
            }
          }
        }
      }
    }
  }
}
