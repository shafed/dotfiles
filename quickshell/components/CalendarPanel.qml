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

  function goToday() {
    var now = view.shell.clockNow
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    view.shell.calendarMonth = new Date(today.getFullYear(), today.getMonth(), 1)
    view.selectedDate = today
    view.system.calendar.loadMonth(view.shell.calendarMonth)
  }

  function isViewingToday() {
    return view.shell.sameCalendarDay(view.selectedDate, view.shell.clockNow)
  }

  onSelectedDateChanged: Qt.callLater(function() {
    if (agendaList.count > 0) agendaList.positionViewAtBeginning()
  })

  Connections {
    target: view.shell

    function onOpenPanelChanged() {
      if (view.shell.openPanel !== "calendar") return
      view.goToday()
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

    Text {
      Layout.fillWidth: true
      text: Qt.formatDateTime(view.shell.calendarMonth, "MMMM yyyy")
      color: view.colors.fgBright
      font.family: view.ui.barFont
      font.bold: true
      font.pixelSize: 16
      verticalAlignment: Text.AlignVCenter
    }

    ClickButton {
      visible: !view.isViewingToday()
      label: "Today"
      onPressed: view.goToday()
    }

    ClickButton { label: "‹"; onPressed: view.shell.shiftCalendarMonth(-1) }
    ClickButton { label: "›"; onPressed: view.shell.shiftCalendarMonth(1) }

    ClickButton {
      visible: view.system.calendar.configured
      label: view.system.calendar.syncing ? "…" : "↻"
      onPressed: view.system.calendar.sync()
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 7
    columnSpacing: 2
    rowSpacing: 2

    Repeater {
      model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
      Text {
        Layout.fillWidth: true
        Layout.preferredHeight: 22
        text: modelData
        color: view.colors.grayDim
        font.family: view.ui.barFont
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    Repeater {
      model: 42
      Rectangle {
        id: dayCell
        required property int index
        property date cellDate: view.shell.calendarCellDate(index)
        property bool inMonth: cellDate.getMonth() === view.shell.calendarMonth.getMonth() &&
                               cellDate.getFullYear() === view.shell.calendarMonth.getFullYear()
        property bool today: view.shell.sameCalendarDay(cellDate, view.shell.clockNow)
        property bool selected: view.shell.sameCalendarDay(cellDate, view.selectedDate)
        property int eventCount: view.system.calendar.eventsOn(cellDate).length

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 7
        color: dayMouse.containsMouse ? view.colors.bgAlt : "transparent"

        Rectangle {
          id: dateBadge
          width: 28
          height: 28
          radius: 14
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: 1
          color: dayCell.selected ? view.colors.yellow : "transparent"
          border.width: dayCell.today && !dayCell.selected ? 1 : 0
          border.color: view.colors.yellow

          Text {
            anchors.centerIn: parent
            text: dayCell.cellDate.getDate()
            color: dayCell.selected
                   ? view.colors.bgHard
                   : dayCell.today
                     ? view.colors.yellow
                     : dayCell.inMonth
                       ? view.colors.fgBright
                       : view.colors.bgMuted
            font.family: view.ui.barFont
            font.pixelSize: 13
            font.bold: dayCell.selected || dayCell.today
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 3
          spacing: 2
          opacity: dayCell.inMonth ? 1 : 0.35

          Repeater {
            model: Math.min(dayCell.eventCount, 3)
            Rectangle {
              width: 4
              height: 4
              radius: 2
              color: view.colors.yellow
            }
          }
        }

        MouseArea {
          id: dayMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var picked = new Date(dayCell.cellDate.getFullYear(), dayCell.cellDate.getMonth(), dayCell.cellDate.getDate())
            if (!dayCell.inMonth)
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

  RowLayout {
    visible: view.system.calendar.setupState === "ready"
    Layout.fillWidth: true

    Text {
      Layout.fillWidth: true
      text: (view.isViewingToday() ? "TODAY · " : "") + Qt.formatDateTime(view.selectedDate, "dddd, d MMMM").toUpperCase()
      color: view.colors.yellow
      font.family: view.ui.bodyFont
      font.bold: true
      font.pixelSize: 12
      elide: Text.ElideRight
    }

    Text {
      visible: view.agendaEvents.length > 0
      text: String(view.agendaEvents.length) + (view.agendaEvents.length === 1 ? " EVENT" : " EVENTS")
      color: view.colors.grayDim
      font.family: view.ui.bodyFont
      font.pixelSize: 10
    }
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
      height: 50
      radius: 6
      color: eventMouse.containsMouse ? view.colors.bgHover : view.colors.bgSoft

      Rectangle {
        width: 3
        height: parent.height - 14
        radius: 2
        anchors.left: parent.left
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        color: view.colors.yellow
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 10
        spacing: 10

        Text {
          Layout.preferredWidth: 80
          text: view.system.calendar.timeLabel(modelData)
          color: view.colors.grayDim
          font.family: view.ui.bodyFont
          font.pixelSize: 10
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            Layout.fillWidth: true
            text: modelData.title
            color: view.colors.fgBright
            font.family: view.ui.barFont
            font.pixelSize: 12
            elide: Text.ElideRight
          }

          Text {
            visible: Boolean(modelData.calendar || modelData.location)
            Layout.fillWidth: true
            text: (modelData.calendar ? modelData.calendar : "") +
                  (modelData.calendar && modelData.location ? " · " : "") +
                  (modelData.location ? modelData.location : "")
            color: view.colors.grayDim
            font.family: view.ui.bodyFont
            font.pixelSize: 9
            elide: Text.ElideRight
          }
        }
      }

      MouseArea {
        id: eventMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
      }
    }
  }

  Item { Layout.fillHeight: true; visible: !agendaList.visible }
}
