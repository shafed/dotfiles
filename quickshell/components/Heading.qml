import QtQuick
import QtQuick.Layouts
import "../config" as Config

Text {
  Config.Colors { id: colors }
  Config.UiConfig { id: ui }
  color: colors.yellow
  font.family: ui.bodyFont
  font.bold: true
  font.pixelSize: ui.headingSize
  Layout.topMargin: 6
}
