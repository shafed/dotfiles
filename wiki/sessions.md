---
title: sessions
type: topic
updated: 2026-08-14
covers:
  - kitty/sessions
  - kitty/scripts
  - scripts/nvim-edit-handler.sh
  - scripts/daily-notes.sh
  - scripts/obsidian-sync.sh
  - scripts/kitty-new-window.sh
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

- `pull`: `git pull --rebase --autostash` on every entry. The former 30-second
  throttle was removed: avoiding one nearby fetch was not worth the extra
  marker state or the small window in which a fresh remote update was skipped.
  On failure it prints to stderr and exits nonzero; since the session files
  chain with `&&`, that stops nvim from launching silently on top of a broken
  pull — you land in the shell with the error visible instead. Sync failures
  also request a critical desktop notification that expires after three seconds.
- `push`: `git add -A`, commit only if there's something staged, always
  `git push` (so an earlier unpushed commit doesn't get stuck waiting for a
  new change).
- `pull` and `push` share a blocking, vault-specific `flock`. Exit/focus
  autocmds can launch overlapping pushes, and session entry can overlap either;
  serializing the whole Git operation prevents index-lock races without
  silently dropping a sync attempt.

`nvim/lua/utils/obsidian.lua` calls `push` two ways, since a single
async-fire-and-forget path used to be both killable mid-flight by nvim
exiting and silently skippable by its own cooldown at the worst time:

- `push_with_cooldown` (bound to `FocusLost`): async (`jobstart`), gated by a
  1h cooldown — best-effort, so alt-tabbing doesn't spam commits/pushes.
- `push_now` (bound to `QuitPre`/`VimSuspend`/`VimLeavePre`, and `<leader>go`):
  detached and **ignores the cooldown**. Exit events are the last opportunity
  to start a push before the process disappears, so they must not be skipped
  just because a recent `FocusLost` push already consumed the cooldown window.
  It survives Neovim and kitty exiting, but remains best-effort: network or
  system shutdown failures are reported rather than treated as guaranteed.

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

Splits: `kitty_mod+backslash` = vsplit (`launch --location=vsplit --cwd=current`) — the
only split binding that exists; there is no hsplit binding.
`C-h/j/k/l` — context-aware split/window navigation via `pass_keys.py` (passes through
in nvim/fzf, otherwise moves between kitty windows).

⚠️ Gotcha (`tab.layout`): tab title and session filter are tied to
`session_name`/`tab.active_wd`; session files set `layout` explicitly on the first
line. The former `M-t` split toggle is absent in the current kitty.conf —
splits now go through `kitty_mod+backslash` (`launch --location=vsplit --cwd=current`).

⚠️ Gotcha (`tall` vs `horizontal` layout, and kitty's counter-intuitive naming):
all session files (and the generators in `kitty-zoxide-session.sh` /
`daily-notes.sh`) used `layout tall` — one main window plus a stack. Under
`tall`, `--location=vsplit` only has an effect for the *second* window; a
third+ window gets added to the stack (top-to-bottom), ignoring the requested
direction, because `tall`'s own placement algorithm
(`/usr/lib/kitty/kitty/layout/tall.py`) doesn't consult `--location` beyond
that. Switched every session file to `layout horizontal` so every window is
always a new side-by-side column (opens to the right), regardless of window
count. ⚠️ kitty's layout names describe the axis windows are *distributed
along*, not the divider orientation — `horizontal` (`main_axis_layout =
Layout.xlayout`, neighbors left/right) tiles windows in a horizontal row
side-by-side; `vertical` (`Layout.ylayout`, neighbors top/bottom) stacks them
in a vertical column instead, i.e. the opposite of what the names suggest at
a glance (`/usr/lib/kitty/kitty/layout/vertical.py`). To apply to already-open
tabs without recreating them: `kitten @ goto-layout --match all horizontal`.

⚠️ Gotcha (`kitty_mod+t` / new tab scope): `session_name` is only assigned to a tab
when it's created *inside* a session (loaded from a `.kitty-session` file, or via
`--add-to-session`). A plain `new_tab` gets no `session_name`, and
`tab_bar_filter session:~ or session:^$` always shows session-less tabs (`^$`
matches "no session") — so such a tab appears regardless of which session is
active, i.e. it isn't scoped to "current session" at all. Fixed by mapping
`kitty_mod+t` to `launch --type=tab --cwd=current --add-to-session .`, which tags
the new tab with the source window's session.

⚠️ Gotcha (orphan kitty processes / "invisible" tabs): `--add-to-session .`
*inherits* the source window's session — blank or not. A bare `exec kitty`
(Hyprland's old `bind = $mainMod, return, exec, $terminal`) starts a brand-new,
independent process with no source window at all, so its first tab gets
`session_name: ""` permanently; `kitty_mod+t` pressed inside it then inherits
that same blank, so every tab spawned from that process stays invisible to
`kitty-list-sessions.sh`'s `select(.session_name != null and .session_name !=
"")` filter — with nothing to explain why. It's also a second, untracked
kitty process, so `main_kitty_socket()` (`../scripts/lib.sh`) may not even be
querying it. Fixed by routing Super+Return through
[`../scripts/kitty-new-window.sh`](../scripts/kitty-new-window.sh)
(`hypr/hyprland.lua:235`) instead of a bare `exec`: it resolves the running
main kitty's socket and does `launch --type=os-window --add-to-session .`
against it, so "new terminal" is always a new OS window inside the one
tracked process — tagged into a session like everything else — falling back
to a plain `exec kitty` only on a cold start with no main kitty yet (login's
`hl.on("hyprland.start", ...)` hook is left as a bare launch for exactly that
reason — nothing exists yet to inherit from).
