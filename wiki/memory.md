---
title: memory
type: topic
updated: 2026-09-26
covers:
  - .claude/hooks/session-memory.sh
  - .claude/settings.json
  - claude/settings.json
  - profiles/base.toml
---

# Memory that survives a session

A session starts with no knowledge of the ones before it. This page covers the
mechanism that closes that gap: a `SessionStart` hook that injects a small,
hand-curated block of facts into every new session, terminal and web alike.

The moving parts are split across two repositories on purpose —
[../.claude/hooks/session-memory.sh](../.claude/hooks/session-memory.sh) here,
the content in the private vault under `.memory/`.

## Why a hook, and not the files that already exist

Two places already carry standing context, and **neither one reaches every
session**:

- [../instructions.md](../instructions.md) is symlinked to `~/.claude/CLAUDE.md`
  (see [global](global.md)), so it exists only on the machine. A Claude Code on
  the web container has no `~/.claude/CLAUDE.md` at all.
- The claude.ai user preferences cover exactly the opposite half: they reach web
  sessions and never the terminal.

`SessionStart` is one of the few hook events whose output Claude Code feeds back
into the model's context — for most events stdout only reaches the debug log.
That makes a hook the one delivery path spanning both halves.

## Why the content is not in this repo

**`shafed/dotfiles` is public.** The memory names private repositories and
personal facts, so it lives in the private vault (`obsidian/.memory/`) and this
repo carries only the mechanism. The split also keeps the rule from
[cli-agents](cli-agents.md): one real file per concept, with the payload shared
and only the wiring duplicated.

Inside the vault it sits in a **hidden** folder, and `.memory` is listed in
`reindex.py`'s `SKIP_DIRS`. Both are needed: `rglob("*.md")` descends into
hidden directories, so without the `SKIP_DIRS` entry the memory files would be
loaded as notes and start appearing in generated indexes.

⚠️ **Gotcha**: a hidden folder is invisible in the Obsidian mobile app. The
memory is editable from Neovim on the machine, but not from the phone. If that
becomes a problem, the fix is a visible folder plus the same `SKIP_DIRS` entry —
not dropping the entry.

## Registration: one script, two call sites

| Where                          | Command             | Covers              |
| ------------------------------ | ------------------- | ------------------- |
| `~/.claude/settings.json`      | `session-memory.sh` | every local project |
| `<repo>/.claude/settings.json` | `… --remote-only`   | web sessions        |

Registered repo-side in `dotfiles`, `obsidian` and `study`. Only this repo calls
the script by `$CLAUDE_PROJECT_DIR`; the other two reach it as a sibling
checkout, `$CLAUDE_PROJECT_DIR/../dotfiles/.claude/hooks/…`, which resolves
under both layouts — `~/github/<repo>` on the machine and `/home/user/<repo>` in
a container — and tests the path first so a missing checkout is a silent no-op
rather than a hook error.

**`21-algorithms-data-structures` is deliberately left out**, although a web
session reaches it too. It is coursework shared with an instructor, so agent
configuration does not belong in it. Registering it there was proposed and
rejected; do not add it back as an oversight. A session started in that
repository simply gets no memory, which is the same silent no-op as any other
unconfigured repository.

⚠️ **Gotcha**: a web session therefore needs **both** `dotfiles` (the script)
and `obsidian` (the content) in its repository scope. With either one missing
the session starts with no memory and says nothing about it — the hook cannot
distinguish "not configured" from "nothing to load", and treating it as an error
would break every session that legitimately has no vault.

⚠️ **Gotcha**: hook entries from the user level and the project level **merge,
they do not override**. Registered plainly in both places, the hook fires twice
inside a repo that also registers it, and the whole memory lands in context
twice. `--remote-only` gates the repo-side call on `CLAUDE_CODE_REMOTE`, so
exactly one of the two ever fires. A lock keyed on the session id was rejected
for this: both registrations fire within the same instant, so the guard would
have needed a timing window, and a timing window fails silently.

The local half is applied by `dots`, not by hand.
[../profiles/base.toml](../profiles/base.toml) links the script to
`~/.claude/hooks/session-memory.sh`, and the registration sits in the tracked
[../claude/settings.json](../claude/settings.json), which `base.toml` links to
`~/.claude/settings.json`. The same file registers `no-coauthor.sh` and
`format.sh`.

Until 2026-09-26 a `claude-user-hooks` generator merged these registrations
into a real `~/.claude/settings.json`, on the assumption that Claude Code's own
writes to that file would clobber a symlink. A probe showed Claude Code writes
through the link, so the generator was removed — the evidence and the new
gotchas are in [global](global.md).

## What the hook deliberately does not do

- **It does not fire on `resume`.** A resumed session replays a transcript that
  already carries the block from its first start. It does fire on `clear` and
  `compact`, which drop it.
- **It never fails a session.** No vault in reach — another machine, a container
  without it — is a normal condition, not an error: it prints nothing and
  exits 0.
- **It never writes.** Memory is updated only when asked for, which is the rule
  the vault's own `CLAUDE.md` already sets for notes. Automatic session
  summaries were rejected outright: they would violate that rule, and within
  weeks the memory would be exhaust rather than signal.

## The write path is slow, and that is accepted

⚠️ **Gotcha**: the vault's Git remote is not the machine's inbound path.
`../scripts/obsidian-git-view-sync.sh` never runs `pull`, `merge` or `checkout`
— it only lets Git metadata catch up to what Syncthing already delivered, and
parks at `waiting: working files do not yet match origin/main` until they match.
So memory edited from a web session does not appear on the machine when the push
lands; it arrives by whatever route also carries the Telegram agent's GitHub-API
writes (`shafed/telegram-github-agent`), which has not been traced here.

Consequence: treat web-session memory edits as eventually consistent, and make
them from the machine when the next session needs them promptly.

## Budget

Every line is loaded into every session of every project, so the bar is the one
[global](global.md) sets for `instructions.md`: a line earns its place only when
an agent could not recover the fact by looking, and being wrong about it would
change what the agent does. `obsidian/.memory/README.md` restates this where the
content lives.

## Rejected

- **Memory in this repo.** Simplest wiring, but `shafed/dotfiles` is public.
- **A dedicated private repository.** Clean bidirectional Git with no Syncthing
  in the way, but it would have to be cloned into every web session to be
  readable, for content the vault already carries everywhere.
- **An `@` import from `instructions.md`.** Native and free, but it resolves
  relative to the importing file — which is a symlink — and it reaches only the
  machine, which is the half that was already covered.
