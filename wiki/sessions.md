---
title: sessions
type: topic
updated: 2026-08-14
covers:
  - kitty/sessions
  - kitty/scripts
  - scripts/kitty-new-window.sh
---

# sessions — native kitty sessions

How they're driven: [kanata](kanata.md), [keymap](keymap.md). Why tmux was
dropped at all: [decisions](decisions.md).

## What replaced tmux

Sessions are kitty-native: declarative session files in
[`../kitty/sessions/`](../kitty/sessions/), `goto_session` to create-or-switch
by name, and `tab_bar_filter session:~ or session:^$` to show only the current
session's tabs.

The one tmux convenience that had to be rebuilt by hand is layout persistence.
`dotfiles`/`projects` sessions call `require("persistence").load()` to emulate
"press s on the start screen". ⚠️ The `obsidian` and daily-note sessions
deliberately do **not** — see the daily-note gotcha below for what goes wrong.

## How kanata drives sessions

kanata's `apps` layer sends `C-S-` hotkeys via `deftemplate kitty-send` (focus
kitty → settle delay → hotkey), which kitty.conf maps to session actions. The
three-layer mapping is only visible here:

| apps key | kitty hotkey | action           |
| -------- | ------------ | ---------------- |
| `h`      | `C-S-a`      | home             |
| `t`      | `C-S-2`      | todos            |
| `w`      | `C-S-w`      | downloads        |
| `o`      | `C-S-o`      | obsidian         |
| `p`      | `C-S-c`      | projects         |
| `d`      | `C-S-d`      | dotfiles         |
| `b`      | `A-tab`      | last session     |
| `e`      | `C-S-f`      | zoxide picker    |
| `c`      | `C-S-s`      | sessions picker  |
| `r`      | `C-S-1`      | daily note       |

## kitty-zoxide-session

[`../kitty/scripts/kitty-zoxide-session.sh`](../kitty/scripts/kitty-zoxide-session.sh)
switches or creates a session by directory. `--named <name>` addresses one
directly (used by the logbook's `nvim-edit://` handler,
[scripts-logbook](scripts-logbook.md)).

Named sessions and zoxide directories show **without** type prefixes — the
former `s-`/`z-` labels were noise, since the picker already distinguishes them
internally. `ssh-` stays, because there the prefix carries real information: the
destination is remote.

## Vault sessions

The `obsidian` session pulls the vault before launching nvim
([scripts-misc](scripts-misc.md) covers `obsidian-sync.sh` itself), and
`daily-notes.sh` generates a throwaway per-day session file.

⚠️ Gotcha (why the daily note never calls `persistence.load()`, settled
2026-07-26): the journal directory is shared by every note, and persistence
overwrites that same cwd-keyed entry on every exit — so restoring it reopens
whatever layout a *previous* day's session left behind. Reordering the calls,
and even opening with `+tabedit` so a fresh tab wins focus, only reduced how
often the wrong thing appeared. A daily note has to be a guarantee rather than
"usually", so the call was dropped outright.

## Splits and layout

`kitty_mod+backslash` = vsplit — the only split binding; there is no hsplit.
`C-h/j/k/l` navigate contextually via `pass_keys.py` ([kitty](kitty.md)). The
former `M-t` split toggle no longer exists in kitty.conf.

⚠️ Gotcha (`tall` vs `horizontal`, and kitty's counter-intuitive names): session
files used `layout tall`, under which `--location=vsplit` only affects the
*second* window — a third window joins the stack top-to-bottom, ignoring the
requested direction, because `tall`'s placement algorithm
(`/usr/lib/kitty/kitty/layout/tall.py`) stops consulting `--location` past that.
Every session file now uses `layout horizontal`, so each new window is a column
to the right regardless of count. ⚠️ kitty's names describe the axis windows are
*distributed along*, not the divider: `horizontal` tiles side-by-side
(neighbors left/right), `vertical` stacks top-to-bottom — the opposite of what
they suggest. Apply to already-open tabs with
`kitten @ goto-layout --match all horizontal`.

⚠️ Gotcha (`kitty_mod+t` / new tab scope): `session_name` is assigned only to
tabs created *inside* a session — from a `.kitty-session` file or via
`--add-to-session`. A plain `new_tab` gets none, and the filter's `session:^$`
clause matches "no session", so such a tab shows up under **every** session.
Fixed by mapping `kitty_mod+t` to
`launch --type=tab --cwd=current --add-to-session .`.

⚠️ Gotcha (orphan processes / invisible tabs): `--add-to-session .` *inherits*
the source window's session — including a blank one. A bare `exec kitty` starts
an independent process with no source window, so its first tab is permanently
`session_name: ""`, and every tab spawned from it inherits that blank and stays
invisible to `kitty-list-sessions.sh`'s non-empty filter, with nothing on screen
explaining why. It is also a second untracked process, which
`main_kitty_socket()` (`../scripts/lib.sh`) may not even be querying. Fixed by
routing `SUPER+Return` through
[`../scripts/kitty-new-window.sh`](../scripts/kitty-new-window.sh), which
resolves the running main kitty and does
`launch --type=os-window --add-to-session .` against it. It falls back to a bare
`exec kitty` only on a cold start — which is also why the login hook in
[hypr](hypr.md) stays a bare launch: nothing exists yet to inherit from.
