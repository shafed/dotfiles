---
title: calendar
type: component
updated: 2026-09-01
covers:
  - vdirsyncer/config
  - vdirsyncer/google-credentials.example
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
Then create the local untracked credentials file:

```sh
mkdir -p ~/.config/vdirsyncer
cp ~/github/dotfiles/vdirsyncer/google-credentials.example \
  ~/.config/vdirsyncer/google-credentials
chmod 600 ~/.config/vdirsyncer/google-credentials
$EDITOR ~/.config/vdirsyncer/google-credentials
```

Fill in `client_id=` and `client_secret=`. The tracked vdirsyncer config fetches
those two values at runtime; the secret file is not linked from the repository.

Authorize and discover the calendars once:

```sh
vdirsyncer discover google_calendar
vdirsyncer sync google_calendar
khal list today 8d
```

After that the user timer keeps the local copy current. New Google calendars may
require running `vdirsyncer discover google_calendar` again.

## Quickshell behavior

`CalendarService.qml` reads the next eight days from `khal` as JSON every two
minutes. It keeps setup/failure states local to the shell and can request the
oneshot systemd sync from the calendar panel's refresh button.

The clock still opens the existing Calendar panel. Days containing events are
marked in the month grid and the panel shows the next four upcoming events.
The top bar adds a compact event button only for today's timed events: before the
event it is `HH:MM title`; while it is in progress it is `NOW title`. All-day
events remain visible in the panel but do not occupy top-bar space.

The synchronization path is deliberately:

```text
Google Calendar -> vdirsyncer -> local .ics vdirs -> khal -> Quickshell
```

This keeps network authentication and CalDAV recurrence parsing outside the QML
UI while preserving Quickshell as the owner of live desktop presentation state.
