import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
  id: view
  required property var shell
  required property var system
  required property var colors
  required property var ui

  property date selectedDate: new Date(shell.clockNow.getFullYear(), shell.clockNow.getMonth(), shell.clockNow.getDate())
  property var agendaEvents: {
    var revision = view.system.calendar.events
    return view.system.calendar.eventsOn(view.selectedDate)
  }

  spacing: 10

  Connections {
    target: view.shell

    function onOpenPanelChanged() {
      if (view.shell.openPanel !== "calendar") return
      var now = view.shell.clockNow
      view.selectedDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
      view.system.calendar.loadMonth(view.shell.calendarMonth)
    }

    function onCalendarMonthChanged() {
      if (view.selectedDate.getFullYear() !== view.shell.calendarMonth.getFullYear() ||
          view.selectedDate.getMonth() !== view.shell.calendarMonth.getMonth()) {
        view.selectedDate = new Date(view.shell.calendarMonth.getFullYear(), view.shell.calendarMonth.getMonth(), 1)
      }
      view.system.calendar.loadMonth(view.shell.calendarMonth)
    }
  }

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
        property bool inMonth: cellDate.getMonth() === view.shell.calendarMonth.getMonth() &&
                               cellDate.getFullYear() === view.shell.calendarMonth.getFullYear()
        property bool today: view.shell.sameCalendarDay(cellDate, view.shell.clockNow)
        property bool selected: view.shell.sameCalendarDay(cellDate, view.selectedDate)
        property bool hasEvent: view.system.calendar.hasEventsOn(cellDate)
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 5
        color: selected ? view.colors.yellow : "transparent"
        border.width: selected ? 0 : 1
        border.color: today || hasEvent ? view.colors.yellow : (inMonth ? view.colors.bgSoft : "transparent")

        Text {
          anchors.centerIn: parent
          text: parent.cellDate.getDate()
          color: parent.selected ? view.colors.bgHard : (parent.inMonth ? view.colors.fgBright : view.colors.bgMuted)
          font.family: view.ui.barFont
          font.pixelSize: 14
          font.bold: parent.selected || parent.today || parent.hasEvent
        }

        Rectangle {
          visible: parent.hasEvent && !parent.selected
          width: 4
          height: 4
          radius: 2
          color: view.colors.yellow
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 3
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var picked = new Date(parent.cellDate.getFullYear(), parent.cellDate.getMonth(), parent.cellDate.getDate())
            if (!parent.inMonth)
              view.shell.calendarMonth = new Date(picked.getFullYear(), picked.getMonth(), 1)
            view.selectedDate = picked
          }
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
          ? "Google Calendar is not connected. Add the OAuth client values under ~/.local/state/dotfiles/secrets/google-calendar/."
          : view.system.calendar.setupState === "discover"
            ? "OAuth is not finished. Run: vdirsyncer discover google_calendar"
            : view.system.calendar.setupState === "error"
              ? "Calendar: " + view.system.calendar.error
              : "Loading calendar…"
  }

  Text {
    visible: view.system.calendar.setupState === "ready"
    text: Qt.formatDateTime(view.selectedDate, "dddd, d MMMM").toUpperCase()
    color: view.colors.yellow
    font.family: view.ui.bodyFont
    font.bold: true
    font.pixelSize: 12
  }

  Text {
    visible: view.system.calendar.setupState === "ready" && view.agendaEvents.length === 0
    Layout.fillWidth: true
    text: "No events"
    color: view.colors.grayDim
    font.family: view.ui.bodyFont
    font.pixelSize: 12
  }

  ListView {
    id: agendaList
    visible: view.system.calendar.setupState === "ready" && view.agendaEvents.length > 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 6
    model: view.agendaEvents

    delegate: Rectangle {
      required property var modelData
      width: agendaList.width
      height: 42
      radius: 5
      color: view.colors.bgSoft

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Text {
          Layout.preferredWidth: 88
          text: view.system.calendar.timeLabel(modelData)
          color: view.colors.grayDim
          font.family: view.ui.bodyFont
          font.pixelSize: 10
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

  Item { Layout.fillHeight: true; visible: !agendaList.visible }
}
