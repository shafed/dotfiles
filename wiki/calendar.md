---
title: calendar
type: component
updated: 2026-09-01
covers:
  - vdirsyncer/config
  - khal/config
  - quickshell/services/CalendarService.qml
  - quickshell/components/CalendarPanel.qml
  - quickshell/components/TopBar.qml
  - systemd/user/google-calendar-sync.service
  - systemd/user/google-calendar-sync.timer
---

# Google Calendar

Google Calendar is synchronized to local vdirs with `vdirsyncer`; `khal` is the
read-only normalization boundary used by Quickshell. Quickshell does not call the
Google API directly and OAuth credentials/tokens never belong in the repository.

The desktop profile installs `vdirsyncer`, `khal` and the Google OAuth support
module. It links the tracked vdirsyncer/khal configs and enables
`google-calendar-sync.timer`, which runs every five minutes after OAuth has
created `~/.local/state/vdirsyncer/google-token`.

## One-time Google setup

Create a Google OAuth **Desktop application** with the **CalDAV API** enabled.
The two OAuth client values live outside the managed config tree under
`${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/secrets/google-calendar/`, in
`client-id` and `client-secret`. Keep the directory private and both files mode
`600`.

The tracked vdirsyncer config reads those files with vdirsyncer's `command`
fetch strategy. It deliberately does not parse a combined `key=value` file with
`sed` or another text pipeline.

Authorize and discover the calendars once:

```sh
vdirsyncer discover google_calendar
vdirsyncer sync google_calendar
khal list today 8d
```

Google may hide subscribed/shared calendars from CalDAV discovery until they are
selected at `https://calendar.google.com/calendar/syncselect`. After changing
that selection, run `vdirsyncer discover google_calendar` again and accept any
new local collections before syncing. Google CalDAV can still fail to expose
some shared calendars; that is an upstream Google/vdirsyncer limitation rather
than a Quickshell filter.

After that the user timer keeps the local copy current. New Google calendars may
require running discovery again.

## Quickshell behavior

`CalendarService.qml` reads the 42-day range represented by the visible month
grid from `khal` as JSON and refreshes it every two minutes. Moving to another
month reloads that six-week range. `khal list --json` emits one compact JSON
array per queried day, so the service parses each non-empty output line and
flattens those daily arrays before normalizing and sorting the events.

The clock opens the Calendar panel. Calendar days are clickable and the agenda
below always belongs to the selected day. The month grid deliberately gives each
state one visual meaning: a filled Gruvbox-yellow circle is the selected date, a
thin yellow ring is today when today is not selected, and one to three small
dots indicate that the day contains events. Ordinary day cells have no border;
hover uses only a soft background. Dates outside the current month are muted but
remain clickable and switch the visible month when selected.

The header provides previous/next month navigation, manual sync, and a `Today`
action whenever another date is selected. The agenda uses the remaining panel
height as a scrollable list, shows the selected date and event count, and keeps
time, title, calendar name and location visually separated so dense study days
remain scannable.

Calendar events are deliberately not shown in the top bar; the clock remains the
single entry point. The panel refresh button requests the oneshot systemd sync
and then reloads the currently visible month.

The synchronization path is deliberately:

```text
Google Calendar -> vdirsyncer -> local .ics vdirs -> khal -> Quickshell
```

This keeps network authentication and CalDAV recurrence parsing outside the QML
UI while preserving Quickshell as the owner of live desktop presentation state.
