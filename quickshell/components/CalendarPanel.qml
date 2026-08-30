import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
  id: view
  required property var shell
  required property var colors
  required property var ui

  spacing: 10
  RowLayout {
    Layout.fillWidth: true
    ClickButton { label: "‹"; onPressed: view.shell.shiftCalendarMonth(-1) }
    Text {
      Layout.fillWidth: true
      text: Qt.formatDateTime(view.shell.calendarMonth, "MMMM yyyy")
      color: view.colors.fgBright
      font.family: view.ui.barFont
      font.bold: true
      font.pixelSize: 16
      horizontalAlignment: Text.AlignHCenter
    }
    ClickButton { label: "›"; onPressed: view.shell.shiftCalendarMonth(1) }
  }
  GridLayout {
    Layout.fillWidth: true
    columns: 7
    columnSpacing: 4
    rowSpacing: 4
    Repeater {
      model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
      Text {
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        text: modelData
        color: view.colors.grayDim
        font.family: view.ui.barFont
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
    Repeater {
      model: 42
      Rectangle {
        required property int index
        property date cellDate: view.shell.calendarCellDate(index)
        property bool inMonth: cellDate.getMonth() === view.shell.calendarMonth.getMonth()
        property bool today: view.shell.sameCalendarDay(cellDate, view.shell.clockNow)
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 5
        color: today ? view.colors.yellow : "transparent"
        border.width: inMonth && !today ? 1 : 0
        border.color: view.colors.bgSoft
        Text {
          anchors.centerIn: parent
          text: parent.cellDate.getDate()
          color: parent.today ? view.colors.bgHard : (parent.inMonth ? view.colors.fgBright : view.colors.bgMuted)
          font.family: view.ui.barFont
          font.pixelSize: 14
          font.bold: parent.today
        }
      }
    }
  }
  Item { Layout.fillHeight: true }
}
