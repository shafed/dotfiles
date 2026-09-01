import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
  id: view
  required property var shell
  required property var system
  required property var colors
  required property var ui

  property var agendaEvents: view.system.calendar.upcoming(4)

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
    ClickButton {
      visible: view.system.calendar.configured
      label: view.system.calendar.syncing ? "…" : "↻"
      onPressed: view.system.calendar.sync()
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
        Layout.preferredHeight: 22
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
        property bool hasEvent: view.system.calendar.hasEventsOn(cellDate)
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 5
        color: today ? view.colors.yellow : "transparent"
        border.width: inMonth && !today ? 1 : 0
        border.color: hasEvent ? view.colors.yellow : view.colors.bgSoft
        Text {
          anchors.centerIn: parent
          text: parent.cellDate.getDate()
          color: parent.today ? view.colors.bgHard : (parent.inMonth ? view.colors.fgBright : view.colors.bgMuted)
          font.family: view.ui.barFont
          font.pixelSize: 14
          font.bold: parent.today || parent.hasEvent
        }
        Rectangle {
          visible: parent.hasEvent && !parent.today
          width: 4
          height: 4
          radius: 2
          color: view.colors.yellow
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 3
        }
      }
    }
  }

  Text {
    visible: view.system.calendar.setupState !== "ready"
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: view.system.calendar.setupState === "error" ? view.colors.red : view.colors.grayDim
    font.family: view.ui.bodyFont
    font.pixelSize: 12
    text: view.system.calendar.setupState === "credentials"
          ? "Google Calendar is not connected. Add ~/.config/vdirsyncer/google-credentials."
          : view.system.calendar.setupState === "discover"
            ? "OAuth is not finished. Run: vdirsyncer discover google_calendar"
            : view.system.calendar.setupState === "error"
              ? "Calendar: " + view.system.calendar.error
              : "Loading calendar…"
  }

  Text {
    visible: view.system.calendar.setupState === "ready"
    text: "UPCOMING"
    color: view.colors.yellow
    font.family: view.ui.bodyFont
    font.bold: true
    font.pixelSize: 12
  }

  Text {
    visible: view.system.calendar.setupState === "ready" && view.agendaEvents.length === 0
    Layout.fillWidth: true
    text: "No upcoming events in the next 8 days"
    color: view.colors.grayDim
    font.family: view.ui.bodyFont
    font.pixelSize: 12
  }

  Repeater {
    model: view.agendaEvents
    Rectangle {
      required property var modelData
      Layout.fillWidth: true
      Layout.preferredHeight: 42
      radius: 5
      color: view.colors.bgSoft

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Text {
          Layout.preferredWidth: 88
          text: view.system.calendar.dayLabel(modelData, view.shell.clockNow) + "\n" +
                view.system.calendar.timeLabel(modelData)
          color: view.colors.grayDim
          font.family: view.ui.bodyFont
          font.pixelSize: 10
          lineHeight: 0.95
        }

        Text {
          Layout.fillWidth: true
          text: modelData.title + (modelData.location ? "\n" + modelData.location : "")
          color: view.colors.fgBright
          font.family: view.ui.barFont
          font.pixelSize: 12
          elide: Text.ElideRight
          maximumLineCount: 2
        }
      }
    }
  }

  Item { Layout.fillHeight: true }
}
