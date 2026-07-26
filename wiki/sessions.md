---
title: sessions
type: topic
updated: 2026-07-26
covers:
  - kitty/sessions
  - kitty/scripts
  - scripts/nvim-edit-handler.sh
  - scripts/daily-notes.sh
---

# sessions — native kitty sessions

🚧 Partially filled in. See [kanata](kanata.md) (how they're driven) and [keymap](keymap.md).

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
had to be reproduced by hand. For example the daily-note session emulates the old
"press s on the start screen" via `require("persistence").load()` in nvim.

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

## obsidian session and training logbook

The `obsidian` session ([`../kitty/sessions/obsidian.kitty-session`](../kitty/sessions/obsidian.kitty-session))
launches a plain nvim in `~/obsidian` after `git pull`. It intentionally does
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

## daily-notes.sh — status (tmux is no longer used)

⚠️ Fact as of 2026-07-01: the shebang **comment** in
[`../scripts/daily-notes.sh`](../scripts/daily-notes.sh) still says "tmux
session", but the code **doesn't use** tmux. The script generates a temporary
kitty session file at `~/.cache/kitty-sessions/daily-<note>.kitty-session` and
calls `kitten @ action goto_session`. One kitty session per day, nvim with
`persistence.load()`. The comment is stale — worth fixing at some point, the behavior
is already native-kitty.

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
