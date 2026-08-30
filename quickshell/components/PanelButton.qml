import QtQuick
import QtQuick.Layouts
import "../config" as Config

Rectangle {
  id: button
  property string label: ""
  property bool selected: false
  signal pressed()

  Config.Colors { id: colors }
  Config.UiConfig { id: ui }

  Layout.fillWidth: true
  implicitHeight: ui.panelButtonHeight
  radius: ui.panelButtonRadius
  color: selected ? colors.bgHover : (mouse.containsMouse ? colors.bgSoft : colors.bg)
  border.width: 1
  border.color: colors.bgHover

  Text {
    anchors.left: parent.left
    anchors.leftMargin: ui.panelButtonTextMargin
    anchors.verticalCenter: parent.verticalCenter
    text: button.label
    color: colors.fgBright
    font.family: ui.bodyFont
    font.pixelSize: ui.panelButtonTextSize
    elide: Text.ElideRight
    width: parent.width - 2 * ui.panelButtonTextMargin
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.pressed()
  }
}
