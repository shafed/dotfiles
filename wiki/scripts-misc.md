---
title: scripts-misc
type: component
updated: 2026-08-31
covers:
  - scripts/watch-downloads.sh
  - scripts/sudo-notify.sh
  - scripts/obsidian-sync.sh
  - scripts/daily-notes.sh
  - scripts/symlayout-watch.sh
  - scripts/open-url.sh
---

# scripts — standalone helpers

Parent: [scripts](scripts.md). Unrelated one-off scripts; each section is
self-contained.

## watch-downloads.sh — Downloads clipboard watcher

Run by the user systemd unit `systemd/user/watch-downloads.service`. It watches
`~/Downloads` with `inotifywait` and copies each completed download to the
clipboard:

- image files (`png`, `jpg`, `webp`, etc.) are copied as `image/*` via CopyQ,
  with `text/plain` and `text/uri-list` alongside it, so browsers/Claude paste
  the bitmap instead of literal `file://...` text;
- non-image files are copied as `text/uri-list`, which `mini.files` can paste
  into the current directory with `<leader>p`.

The unit intentionally starts the script from `~/github/dotfiles/scripts/` rather than
`~/.local/bin`, so the behavior is versioned with the rest of the dotfiles.

## sudo-notify.sh — sudo password-prompt notifier

`~/.local/bin/sudo` is a thin wrapper (`exec ".../scripts/sudo-notify.sh" "$@"`,
same shape as `nvim-edit-handler`) that shadows `/usr/bin/sudo` earlier in
`$PATH` (`zsh/zshrc` puts `~/.local/bin` first). The real logic lives here so
it's versioned with the rest of the dotfiles instead of only existing as an
unversioned file in `~/.local/bin`. `dots apply`'s `install_links` step writes
this wrapper, so a fresh `git clone` + `./dots apply` gets the notification
working with no manual step.

Sends a `notify-send` if a sudo call is about to block on a password **and** the
terminal window it's running in isn't currently focused (Hyprland-only, via
`hyprctl activewindow`) — otherwise a password prompt sitting in a background
terminal goes unnoticed. Design:

- First does `sudo -n true` (non-interactive credential check): if a valid sudo
  timestamp already exists, no prompt will occur, so it skips the notification
  path entirely.
- Otherwise walks up the process tree from its own PID (capped at 12 hops) to
  find the enclosing terminal emulator (`TERMINAL_COMMS` — kitty, alacritty,
  foot, etc.), and compares that PID against Hyprland's active window PID.
- Always `exec`s the real `/usr/bin/sudo` at the end regardless of the notify
  path, so behavior/exit code/stdio are byte-identical to calling sudo directly
  — this wrapper is meant to be fully transparent.

## obsidian-sync.sh

Shared git sync for `~/github/obsidian`.

- `pull` — `git pull --rebase --autostash`.
- `push` — runs that pull first, then `git add -A`, commits any changes, and
  pushes. Pull-before-commit keeps remote edits and removed lines from being
  overwritten by a stale local copy when the changes do not conflict.
- If the rebase leaves an actual Git conflict, sync stops before staging it.
- Pull and push share one vault-specific `flock` so overlapping Neovim events
  cannot race over the Git index.

Android's Termux helper should use the same simple order: pull/rebase first,
then add → commit → push.

Call sites:
[`../kitty/sessions/obsidian.kitty-session`](../kitty/sessions/obsidian.kitty-session)
and `daily-notes.sh` (pull side, see below and [sessions](sessions.md)),
[`../nvim/lua/utils/obsidian.lua`](../nvim/lua/utils/obsidian.lua) (push side —
`push_with_cooldown` for frequent events and detached `push_now` for exit
events; the latter ignores the cooldown so a recent focus-loss push does not eat
the last opportunity to start syncing before Neovim exits).

## daily-notes.sh

Opens today's daily note in nvim inside a **per-day kitty session**
(`daily-<note>.kitty-session`), creating the note on first access. Layout:
`~/github/obsidian/journal/<YYYY-MM-DD-Weekday>.md` — the folder is flat, so the path
must stay in sync with `daily_notes_folder` in the vault's `.moxide.toml`.

On first entry it does `obsidian-sync.sh pull`, then opens straight into the
note (`nvim "+norm G" <full_path>`) — deliberately **no** `persistence.load()`.
Earlier versions tried combining the two for a "reopen last layout" convenience,
but the journal directory is shared by every daily note, so persistence could
restore an older multi-tab layout instead of showing today's note. See
[sessions](sessions.md) for the history.

## symlayout-watch.sh

Forces the `us` layout while kanata's symbol layers are active. Called
**directly by kanata actions** (`enter`/`leave`/`app`), with no TCP server. See
[kanata](kanata.md).

- A POSIX-sh port of the old Python version — about 13ms faster per call (no
  interpreter startup), which matters since it's invoked on every layer
  entry/exit.
- `enter` remembers the current layout index in a state file and switches to
  `us`; `leave` restores the saved index. The state file also guards against a
  double enter.

## open-url.sh

Thin non-interactive wrapper around `open_or_focus_url` (`lib.sh`,
[scripts-pickers](scripts-pickers.md)) — no fzf, no QAT panel. Takes a URL (and
optional tab-name for the title-match tier) as argv and either focuses a
matching already-open tab or opens a new one. Used by kanata's `browser` layer
bindings ([kanata](kanata.md)) so its one-key site shortcuts (ChatGPT, Claude,
Perplexity, Gmail, Reverso) reuse an existing tab instead of piling up
duplicates on every press.
