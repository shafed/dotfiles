---
title: sessions
type: topic
updated: 2026-08-10
covers:
  - kitty/sessions
  - kitty/scripts
  - scripts/nvim-edit-handler.sh
  - scripts/daily-notes.sh
  - scripts/obsidian-sync.sh
  - nvim/lua/utils/obsidian.lua
---

# sessions — native kitty sessions

See [kanata](kanata.md) (how they're driven) and [keymap](keymap.md).

## Migration from tmux to kitty native sessions

Previously sessions/panes were held by tmux (prefix `C-s`). Moved to **native
kitty sessions** (`goto_session`, session files in
[`../kitty/sessions/`](../kitty/sessions/)). Why:

- one less layer — no need for tmux on top of kitty; management (splits, tabs,
  scrollback in nvim) is already in kitty.
- kitty-nativeness: `tab_bar_filter session:~ or session:^$` shows only
  the tabs of the current session; `goto_session` creates-or-switches by file name.
- the session file is declarative: `layout`, `cd`, `launch --title ...`, `focus`.

Trade-off: some tmux conveniences (layout persistence, "reopen last session")
had to be reproduced by hand — see [`../kitty/sessions/dotfiles.kitty-session`](../kitty/sessions/dotfiles.kitty-session)
and `projects.kitty-session`, which call `require("persistence").load()` to
emulate the old "press s on the start screen". The daily-note session
deliberately does **not** do this (see below) — it must always land on the
note itself, not on whatever was last restored for that directory.

## How kanata drives sessions

kanata from the `apps` layer sends `C-S-` hotkeys (`kitty_mod = ctrl+shift`) via
`deftemplate kitty-send` (focus kitty → `aterm-settle` delay → hotkey). See
[kanata](kanata.md). Mapping (kitty.conf, "Session & navigation" section):

- `apps+h → C-S-a` = home, `apps+t → C-S-2` = todos, `apps+w → C-S-w` = downloads,
  `apps+o → C-S-o` = obsidian, `apps+p → C-S-c` = projects, `apps+d → C-S-d` = dotfiles.
- `apps+b → A-tab` = last session (`goto_session -1`).
- `apps+e → C-S-f` = zoxide picker, `apps+c → C-S-s` = list-sessions picker,
  `apps+r → C-S-1` = daily note.

## kitty-zoxide-session

[`../kitty/scripts/kitty-zoxide-session.sh`](../kitty/scripts/kitty-zoxide-session.sh)
(`C-S-f`, overlay) — switch/create a session by directory via zoxide.
Supports `--named <name>` for addressed invocation (used by nvim-edit-handler).
Named session files and zoxide directories are displayed without type prefixes,
and directory-backed sessions use the sanitized directory basename as their
session name. The picker already distinguishes entry types internally, so the
former `s-` and `z-` labels added visual noise without helping selection; SSH
sessions retain `ssh-` because the prefix identifies a remote destination.

## obsidian session and training logbook

The `obsidian` session ([`../kitty/sessions/obsidian.kitty-session`](../kitty/sessions/obsidian.kitty-session))
launches a plain nvim in `~/obsidian` after `obsidian-sync.sh pull` (see
[scripts](scripts.md)). It intentionally does
not call `persistence.load()`: entering the vault should start from nvim's
normal startup state instead of reopening the previous editing layout
automatically.

The training logbook opens files via `nvim-edit://<path>` links, which are
caught by [`../scripts/nvim-edit-handler.sh`](../scripts/nvim-edit-handler.sh) (see
[scripts](scripts.md)). It:
1. finds the main (non-floating) kitty socket,
2. switches to/creates the `obsidian` session via `kitty-zoxide-session.sh --named obsidian`,
3. opens the file as a new tab in the **already running** nvim of that session — first
   via `--server <sock> --remote-tab`, otherwise falls back to `send-text` `:tabedit`.

⚠️ Gotcha: the nvim socket is found by iterating over PIDs near the nvim pid (`delta 0,1,-1,2,...`),
since the exact `nvim.<pid>.0` doesn't always match the foreground process's pid. Fragile
spot — if nvim didn't bring up a `--listen` socket, the send-text fallback kicks in.

### obsidian-sync.sh — vault git sync

The vault syncs across multiple devices, so both directions matter: pulling
remote changes before editing, and getting local edits pushed out promptly.
This used to be three copy-pasted `git pull` one-liners (`obsidian.kitty-session`,
`todos.kitty-session`, `daily-notes.sh`) plus an inline commit/push shell
string built in `nvim/lua/utils/obsidian.lua` — now consolidated into
[`../scripts/obsidian-sync.sh`](../scripts/obsidian-sync.sh) (`pull` / `push`
subcommands), called from all four sites.

- `pull`: `git pull --rebase --autostash`, throttled — skipped if the last
  pull happened less than 30s ago (marker file in `~/.cache/obsidian-sync/`),
  so opening `todos` then `obsidian` back to back doesn't hit the remote
  twice. On failure it prints to stderr and exits nonzero; since the session
  files chain with `&&`, that stops nvim from launching silently on top of a
  broken pull — you land in the shell with the error visible instead.
- `push`: `git add -A`, commit only if there's something staged, always
  `git push` (so an earlier unpushed commit doesn't get stuck waiting for a
  new change).

`nvim/lua/utils/obsidian.lua` calls `push` two ways, since a single
async-fire-and-forget path used to be both killable mid-flight by nvim
exiting and silently skippable by its own cooldown at the worst time:

- `push_with_cooldown` (bound to `FocusLost`): async (`jobstart`), gated by a
  1h cooldown — best-effort, so alt-tabbing doesn't spam commits/pushes.
- `push_sync` (bound to `QuitPre`/`VimSuspend`/`VimLeavePre`, and `<leader>go`):
  synchronous (`vim.fn.system`), **ignores the cooldown**. Exit events are the
  last chance to push before the process disappears, so they must not be
  skipped just because a recent `FocusLost` push already consumed the
  cooldown window — that used to mean edits could sit unpushed across
  devices for up to an hour.

## daily-notes.sh

[`../scripts/daily-notes.sh`](../scripts/daily-notes.sh) generates a temporary
kitty session file at `~/.cache/kitty-sessions/daily-<note>.kitty-session` and
calls `kitten @ action goto_session`. One kitty session per day: pulls via
`obsidian-sync.sh pull` (see [scripts](scripts.md)), then `nvim "+norm G"
<full_path>` — always opens straight into the note, no `persistence.load()`.

⚠️ Gotcha (history, 2026-07-26): earlier versions tried to combine the daily
note with `persistence.load()`, to get the "reopen last layout" convenience
(same rationale discussed above for why the `obsidian` session avoids it, and
why `dotfiles`/`projects` sessions do use it). This never landed the note
reliably: `note_dir` is the *monthly* folder, shared by every day's note that
month, and persistence overwrites that same cwd-keyed session on every exit —
so `persistence.load()` restores whatever multi-tab/multi-window layout was
open when a *previous* day's session exited. Reordering commands
(`persistence.load()` before opening the note) and even opening the note with
`+tabedit` instead of `+edit` (a fresh tab always wins focus) reduced how
often the wrong thing showed up on screen, but the daily note is meant to be a
hard guarantee, not "usually" — so `persistence.load()` was dropped
entirely for this session, the same call the `obsidian` session already
avoids for the same reason.

## Splits and layout

Splits: `C-S--` = hsplit, `C-S-\` = vsplit (`launch --location=... --cwd=current`).
`C-h/j/k/l` — context-aware split/window navigation via `pass_keys.py` (passes through
in nvim/fzf, otherwise moves between kitty windows).

⚠️ Gotcha (`tab.layout`): tab title and session filter are tied to
`session_name`/`tab.active_wd`; session files set `layout` (usually `tall`) explicitly
on the first line. The former `M-t` split toggle is absent in the current kitty.conf —
splits now go through `C-S--` / `C-S-\`.

⚠️ Gotcha (`kitty_mod+t` / new tab scope): `session_name` is only assigned to a tab
when it's created *inside* a session (loaded from a `.kitty-session` file, or via
`--add-to-session`). A plain `new_tab` gets no `session_name`, and
`tab_bar_filter session:~ or session:^$` always shows session-less tabs (`^$`
matches "no session") — so such a tab appears regardless of which session is
active, i.e. it isn't scoped to "current session" at all. Fixed by mapping
`kitty_mod+t` to `launch --type=tab --cwd=current --add-to-session .`, which tags
the new tab with the source window's session.
