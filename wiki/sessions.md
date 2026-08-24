---
title: sessions
type: topic
updated: 2026-08-24
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

| apps key | kitty hotkey | action          |
| -------- | ------------ | --------------- |
| `h`      | `C-S-a`      | home            |
| `t`      | `C-S-2`      | todos           |
| `w`      | `C-S-w`      | downloads       |
| `o`      | `C-S-o`      | obsidian        |
| `p`      | `C-S-c`      | projects        |
| `d`      | `C-S-d`      | dotfiles        |
| `b`      | `A-tab`      | last session    |
| `e`      | `C-S-f`      | zoxide picker   |
| `c`      | `C-S-s`      | sessions picker |
| `r`      | `C-S-1`      | daily note      |

## kitty-zoxide-session

[`../kitty/scripts/kitty-zoxide-session.sh`](../kitty/scripts/kitty-zoxide-session.sh)
switches or creates a session by directory. `--named <name>` addresses one
directly (used by the logbook's `nvim-edit://` handler,
[scripts-logbook](scripts-logbook.md)).

Named sessions and zoxide directories show **without** type prefixes — the
former `s-`/`z-` labels were noise, since the picker already distinguishes them
internally. `ssh-` stays, because there the prefix carries real information: the
destination is remote.

⚠️ Gotcha (`$DOTFILES` is unset when kanata launches these, settled
2026-08-24): `kitty-zoxide-session.sh` and `kitty-list-sessions.sh` used to
resolve their own paths via `dotfiles_dir="$DOTFILES"`. kanata runs as a
systemd `--user` service and invokes these through `zsh -lc "..."` — a
login-but-**not-interactive** shell, so `~/.zshrc` (the only place `$DOTFILES`
is exported) never gets sourced, and neither the service's environment nor
`~/.zprofile`/`~/.zshenv` set it either. The result: `source
"$dotfiles_dir/scripts/lib.sh"` became `source "/scripts/lib.sh"`, which
doesn't exist — `set -e` killed the script before the QAT panel ever launched,
with no visible error (kanata doesn't surface stderr from `cmd`). The other
`apps` pickers (`apps.sh`, `bookmarks.sh`, `youtube-qat.sh`) never had this bug
because they resolve `lib.sh` from their own `BASH_SOURCE` location, not
`$DOTFILES`. Fixed the same way: both scripts now derive `dotfiles_dir` from
`script_path` (two levels up from `kitty/scripts/`) instead of the
environment.

## Vault sessions

The `obsidian` session pulls the vault before launching nvim
([scripts-misc](scripts-misc.md) covers `obsidian-sync.sh` itself), and
`daily-notes.sh` generates a throwaway per-day session file.

⚠️ Gotcha (why the daily note never calls `persistence.load()`, settled
2026-07-26): the journal directory is shared by every note, and persistence
overwrites that same cwd-keyed entry on every exit — so restoring it reopens
whatever layout a _previous_ day's session left behind. Reordering the calls,
and even opening with `+tabedit` so a fresh tab wins focus, only reduced how
often the wrong thing appeared. A daily note has to be a guarantee rather than
"usually", so the call was dropped outright.

## Splits and layout

`kitty_mod+enter` = vsplit — the only split binding; there is no hsplit.
`C-h/j/k/l` navigate contextually via `pass_keys.py` ([kitty](kitty.md)). The
former `M-t` split toggle no longer exists in kitty.conf.

⚠️ Gotcha (`tall` vs `horizontal`, and kitty's counter-intuitive names): session
files used `layout tall`, under which `--location=vsplit` only affects the
_second_ window — a third window joins the stack top-to-bottom, ignoring the
requested direction, because `tall`'s placement algorithm
(`/usr/lib/kitty/kitty/layout/tall.py`) stops consulting `--location` past that.
Every session file now uses `layout horizontal`, so each new window is a column
to the right regardless of count. ⚠️ kitty's names describe the axis windows are
_distributed along_, not the divider: `horizontal` tiles side-by-side (neighbors
left/right), `vertical` stacks top-to-bottom — the opposite of what they
suggest. Apply to already-open tabs with
`kitten @ goto-layout --match all horizontal`.

⚠️ Gotcha (`kitty_mod+t` / new tab scope): `session_name` is assigned only to
tabs created _inside_ a session — from a `.kitty-session` file or via
`--add-to-session`. A plain `new_tab` gets none, and the filter's `session:^$`
clause matches "no session", so such a tab shows up under **every** session.
Fixed by mapping `kitty_mod+t` to
`launch --type=tab --cwd=current --add-to-session .`.

⚠️ Gotcha (`kitty_mod+enter` vsplit losing the session on close — the real bug,
after two false starts): a session opened with `kitty_mod+c` et al., split, then
had its original pane closed, would vanish from `kitty-list-sessions.sh`. Two
live captures (via `kitten @ ls` polling while reproducing in real time) showed
the split's `session_name` was **already blank at creation**, even though its
`cwd` correctly matched the source window's — first with the split done by
whatever key was assumed to be in use, then again after adding
`--add-to-session .` to `kitty_mod+backslash`, which didn't fix it either. Both
rounds of investigation targeted `kitty_mod+backslash`, including an elaborate
workaround (routing the split through `kitten @ launch` over the remote-control
socket via a `--type=background`-launched wrapper script) built to route around
an apparent unreliability in native keymap-dispatched `launch` calls.

That workaround was solving the wrong problem: the user was actually splitting
with **`kitty_mod+enter`**, which this config never mapped at all. Unmapped
`kitty_mod+enter` falls through to kitty's own stock default binding —
`new_window` — a completely different action from `launch`. Plain `new_window`
copies `cwd` (ordinary shell-inheritance default) but never looks at
`created_in_session_name` at all: `boss._new_window()`'s session-copying block
is gated behind `if cwd_from is not None`, and bare `new_window` always calls it
with `cwd_from=None`. So the split was deterministically, 100%-of-the-time
unsessioned by design — not a kitty race or a native-dispatch quirk. Confirmed
with `kitten @ action new_window` reproducing a blank `session_name` on every
call, and
`kitten @ action launch --location=vsplit --cwd=current --add-to-session .`
(invoked the same native way a keypress would) correctly inheriting session_name
on every call — so the `launch`-based approach, and the `--type=background`
workaround built for it, were never actually the problem.

Fixed by explicitly mapping the key actually in use:
`map kitty_mod+enter launch --location=vsplit --cwd=current --add-to-session .`
(no wrapper script needed — the plain `launch` command was always reliable).
`kitty_mod+backslash` was dropped from this config entirely — `kitty_mod+enter`
is now the only split binding.

Lesson: confirm which key the user is actually pressing before trusting a "the
only split binding" claim in this file — a keybinding the user has been using
out of habit can be entirely unmapped here and still work by falling through to
kitty's stock defaults, invisibly, with different (or no) semantics.

⚠️ Gotcha (`focus_main_kitty` race): `goto_kitty_session` (called by the QAT
session pickers) issues `hl.dsp.focus` via `hyprctl dispatch` and returns
immediately — fire-and-forget. A `kitty_mod+t` pressed right after switching
sessions could in theory race that dispatch and resolve `--source-window`
against whatever had OS focus before the switch instead of the just-opened
session, since `--add-to-session .` inherits whatever window kitty considers
active at launch time. `focus_main_kitty` (`../scripts/lib.sh`) now polls
`hyprctl activewindow` for `class == kitty` (bounded, ~1s) before returning, so
by the time the QAT panel hides and control returns to the user, OS focus has
actually landed on the main kitty window.

⚠️ Gotcha (orphan processes / invisible tabs): `--add-to-session .` _inherits_
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
