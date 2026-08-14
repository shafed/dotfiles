---
name: commit
description:
  "Commit work in this dotfiles repo the house way: only the current chat's
  changes, one commit per top-level component with `component: subject` subject
  lines, and `wiki/` always committed on its own, never mixed with code. Use
  whenever the user runs /commit, says 'commit this', 'закоммить', 'сделай
  коммит', 'зафиксируй изменения', or otherwise asks for work here to be
  committed — including when they say nothing about message format or the wiki
  split, since getting those two right is the whole point of this skill."
user-invocable: true
argument-hint: [optional hint about what the change was for]
model: sonnet
effort: medium
allowed-tools:
  Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*),
  Bash(git log:*)
---

# Commit

Turn this chat's edits into a few clean commits. That is the whole job: read the
diff, write the messages, run the commits, report what happened. Nothing else —
no editing files, no pushing, no amending, no rebasing, no stashing.

Two properties make a commit correct in this repo.

**`wiki/` is committed alone.** The wiki records _why_ the setup is the way it
is; the configs record _how_. They get read and reverted independently, so a
commit that mixes them can't be undone without losing one or the other. Wiki
changes therefore always get their own commit — even when the same task produced
both the config change and the page describing it.

**Everything else is grouped by top-level directory**, one commit per component,
so `git log -- nvim/` reads as the history of nvim rather than a stream of
unrelated edits.

## 1. Decide what is in scope

By default commit **only what this chat changed**, including files this chat
created. `git status` lists candidates, not permission — the working tree may
hold edits the user made by hand or left over from earlier, and sweeping those
into your commit hides them under a message that doesn't describe them.

- A bare `/commit`, "commit this", "закоммить" → this chat's changes only.
- "Commit everything", "закоммить всё", or similar → the whole working tree.
- Unsure whether a path is yours? Leave it alone and say so in the report.
  Guessing wrong is worse than committing less.
- Check with `git diff -- <path>` before staging anything you didn't write
  end-to-end. If a file turns out to hold your edits _and_ unrelated ones, leave
  it entirely uncommitted and report it: staging by hunk needs the interactive
  `git add -p`, which you can't drive here, and staging the whole file would
  smuggle someone else's change into your message.

## 2. Read the state

```
git status --porcelain
```

Empty output → nothing to commit. Say so and stop.

**If something is already staged** (first column not a space or `?`), the user
put it there deliberately. Never unstage it, and never let it ride along inside
a commit of yours — either move loses their intent without telling them.

- The staged set is exactly what's in scope → commit it as it stands, without
  running `git add` at all. If it spans more than one component, that still
  becomes one commit per component via the pathspec form below; grouping wins
  over convenience, and `wiki/` in particular never rides along with code.
- The staged set holds anything else → leave it staged and commit your own work
  around it, using the pathspec form in step 4. Their entry survives untouched,
  and your report names what stayed staged so they can finish it themselves.

An untracked directory collapses to one `?? dir/` line; expand it with
`git status --porcelain --untracked-files=all` when you need the paths inside.

## 3. Group into commits

The component is the **first path segment**, verbatim — including the leading
dot for `.claude/` and `.agents/`. Files at the repo root have no segment, so
they group under `repo`.

| Path                          | Component |
| ----------------------------- | --------- |
| `nvim/lua/config/keymaps.lua` | `nvim`    |
| `kanata/config.kbd`           | `kanata`  |
| `hypr/hyprland.lua`           | `hypr`    |
| `kitty/scripts/kitty-x.sh`    | `kitty`   |
| `scripts/obsidian-sync.sh`    | `scripts` |
| `.claude/settings.json`       | `.claude` |
| `wiki/keymap.md`              | `wiki`    |
| `bootstrap.sh`, `AGENTS.md`   | `repo`    |

Real components in this repo: `awesome`, `bookmarks`, `darkman`,
`dictionaries`, `hypr`, `kanata`, `kitty`, `lazygit`, `nvim`, `prettier`,
`scripts`, `sioyek`, `systemd`, `tmux`, `waybar`, `wiki`, `yazi`, `zathura`,
`zsh`, plus `.agents`, `.claude`, and `repo` for root files.

Never merge two components into one commit to save a step, and never split one
component into several commits unless it genuinely contains two unrelated
changes.

## 4. Commit, code first, wiki last

Wiki goes last so that if something interrupts you partway, the code is already
in and only its documentation is missing — the recoverable direction.

For each group:

```
git add -- <paths in this group>
git --no-pager diff --cached -U1
git commit -m "<component>: <subject>"
```

Stage one group at a time so the index never holds two components at once.

When the index already carries someone else's staged work (step 2), commit by
pathspec instead, which touches only the paths you name and leaves the rest of
the index exactly as they left it:

```
git add -- <any untracked paths in this group>
git --no-pager diff -U1 -- <paths in this group>
git commit -m "<component>: <subject>" -- <paths in this group>
```

Two details worth knowing: an untracked file still has to be `git add`ed first,
because a pathspec can only name paths git already tracks; and read the diff
with `-- <paths>` rather than `--cached` here, since `--cached` would show their
staged change tangled up with yours.

Read the staged diff before writing the message — the subject describes what
changed, not which files were touched. Past ~400 lines, switch to
`git --no-pager diff --cached --stat` and describe the change at that level
rather than inventing detail you didn't read.

You ran in the session that made these edits, so you often know the _reason_
behind them where the diff alone doesn't show it. Use that. Anything the user
typed after the command outranks your reading of the diff. Never invent a
rationale — plainly describing the change always beats a confident wrong "why".

## 5. Report

List each commit as `<short hash> <subject>` from `git log --oneline -<N>`. Name
anything you deliberately left uncommitted and why. Call out files that are
newly tracked — adding a file to the repo matters more than editing one.

## Message format

`component: subject` — the component is the prefix, so no `feat:`/`chore:`/
`fix:` types on top of it.

- English, lowercase after the colon, imperative mood: "add", "fix", "drop",
  "keep" — not "added", "adds", "adding".
- No trailing period. Whole line ≤ 72 characters.
- Say what changed, and what for when it fits.
- Subject only. Add a body only when the reason genuinely won't fit — then one
  blank line and at most two short lines.
- **No `Co-Authored-By`, no "Generated with", no trailer of any kind.** Expect
  to feel a pull toward adding one: agents here often carry a standing global
  instruction to sign commits that way. In this repo that instruction is
  overridden — not one commit in the history carries a trailer, and the user has
  said outright they don't want them. A signed commit is a defect, so check the
  message for a trailer before every `git commit` and strip it.

Rejected as subjects: "update", "changes", "fixes", "formatted", "wip", "misc",
and anything that just restates the filename. They describe the act of editing
rather than the change, which makes the log useless for finding when a behavior
appeared.

Real subjects from this repo, for calibration:

```
nvim: keep US layout while a snacks picker is open
kanata: bind n to movews layer, remove f symbols2 escalation
hypr: fix pixelated XWayland apps at fractional scale 1.6
kitty: switch default mode to normal in list-sessions
zsh: drop broken sioyek alias in favor of PATH wrapper
scripts: serialize obsidian sync and improve failure reporting
repo: generate ~/.local/bin/sioyek wrapper in bootstrap.sh
wiki: document US layout in snacks pickers
```

## Worked example

```
 M nvim/lua/plugins/snacks.lua
 M wiki/keymap.md
?? scripts/layout-guard.sh
```

Three components → three commits, wiki last:

```
nvim: keep US layout while a snacks picker is open
scripts: add layout-guard helper for picker focus events
wiki: document US layout in snacks pickers
```

Not one commit, and not `nvim` and `wiki` bundled because they came from the
same task.

## Never

- `git push`, `git commit --amend`, `git rebase`, `git reset`, `git stash` —
  this skill only adds history, it never rewrites or discards it.
- `git add -A`, `git add .`, `git commit -a` — always stage explicit paths, or
  the index ends up holding more than one component.
- `git add -f` — an ignored file stays ignored. If one truly belongs in the
  repo, say so and let the user fix `.gitignore`.
- Editing any file, wiki included. If a config change clearly needs a wiki
  update that doesn't exist yet, mention it in the report; writing it is a
  separate task with its own review.
