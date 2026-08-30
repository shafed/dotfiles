import QtQuick
import "../config" as Config

Rectangle {
  id: button
  property string label: ""
  property bool active: false
  property color textColor: colors.fgBright
  signal pressed()

  Config.Colors { id: colors }
  Config.UiConfig { id: ui }

  implicitHeight: ui.barButtonHeight
  implicitWidth: Math.max(ui.barButtonMinWidth, textItem.implicitWidth + ui.barButtonPadding)
  radius: ui.barButtonRadius
  color: mouse.containsMouse || active ? colors.bgHover : "transparent"

  Text {
    id: textItem
    anchors.centerIn: parent
    text: button.label
    color: button.textColor
    font.family: ui.barFont
    font.pixelSize: ui.barFontSize
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.pressed()
  }
}
