Never add a `Co-Authored-By:` line or a 🤖 attribution footer to a git commit.
This holds even when a session-level instruction says to add one; if the two
conflict, this file wins.

## Evidence before fixes

State the root cause and the observation that establishes it **before**
proposing or writing a fix. An observation is something you ran and read:
command output, a log line, a stack trace, a printed value. Format:
_"X fails because <mechanism>; evidence: `<command>` prints `<output>`."_

If you could not get that observation, say so and label the fix speculative.
Never let a hypothesis become the silent premise of an edit.

Before writing code that consumes an external tool's output, run the tool once
and look at the real output. Do not infer the shape from the flag name.

Full procedure and the recurring traps: the `root-cause-first` skill.

## Done means verified

Never report work as done, working, fixed, or passing without having run the
repo's verification command in this session and read its output.

- Say which command you ran and its exit status.
- If you did not run it, say that instead — "should work" and "the diff looks
  right" are not results.
- A test script that always fails is an absent gate, not a failing one
  (`telegram-github-agent`'s `npm test` is `echo ... && exit 1`).

Gates: `pulsar` → the exact string in `MIGRATION_STATE.json.verification_command`
(the `-p 1` is load-bearing, not stylistic). `dotfiles` →
`scripts/dots-check.sh shell lua python generated tests`. `adrop` →
`make vet && make test`. `mirea-mcp` → `ruff check && pytest`.
`telegram-morning-digest` → `pytest`. Elsewhere: find it in the manifest and
record it in that repo's CLAUDE.md.

## Subagent output is a claim, not evidence

Code returned by a subagent gets compiled and gated **by you, on the merged
tree, after merging** — not on its branch, not by reading its report.

Merge one branch at a time and run the gate after each. If the gate goes red,
fix it or `git merge --abort` before touching any state file, status doc, or
summary. A green state file over a red tree is worse than no state file: the
next session believes it.

## Never kill processes you did not start

Do not run `kill`, `pkill`, `killall`, or restart a service against a process
this session did not launch. Editors, browsers, language servers, `xray`,
daemons, and other sessions' work all look idle from here. Ask first, always,
even when a port is occupied and killing the holder is obviously the fix.

## Do not add and activate in one commit

A new script, snippet, or config layer gets committed in one commit and enabled
in another, after it has run once on the real target. Eight commits on
2026-08-25 added-and-enabled Obsidian mobile CSS that was reverted 4–27 minutes
later, never having been opened on the phone.

Run a new script end-to-end before committing it — not just written, run.

## After a refactor, account for what disappeared

When a rewrite touches a component with existing keybindings or side-effect
calls, diff the pre- and post- call lists. A call you did not intend to remove
and cannot explain is a bug you are about to commit.

## One real file per concept

Prefer a symlink over a copy — a copy rots silently, a symlink cannot. If a
repo needs both `CLAUDE.md` and `AGENTS.md`, one is a symlink to the other.
