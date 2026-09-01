import QtQuick
import "../config" as Config

Rectangle {
  id: button
  property string icon: ""
  property real iconYOffset: 0
  property string label: ""
  property bool active: false
  property color textColor: colors.fgBright
  signal pressed()

  Config.Colors { id: colors }
  Config.UiConfig { id: ui }

  implicitHeight: ui.barButtonHeight
  implicitWidth: Math.max(ui.barButtonMinWidth, contentRow.implicitWidth + ui.barButtonPadding)
  radius: ui.barButtonRadius
  color: mouse.containsMouse || active ? colors.bgHover : "transparent"

  Row {
    id: contentRow
    anchors.centerIn: parent
    spacing: button.icon && button.label ? 5 : 0

    Text {
      visible: button.icon.length > 0
      y: button.iconYOffset
      text: button.icon
      color: button.textColor
      font.family: "Symbols Nerd Font"
      font.pixelSize: ui.barFontSize
    }

    Text {
      visible: button.label.length > 0
      text: button.label
      color: button.textColor
      font.family: ui.barFont
      font.pixelSize: ui.barFontSize
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.pressed()
  }
}
