---
name: commit
description: 'Commit only changes made in the current chat by default, including new files, with unified `component: subject` messages split by top-level component. Use when the user runs /commit, says "commit this", "закоммить", or asks to commit work in this dotfiles repo; include other changes only when explicitly requested.'
user-invocable: true
argument-hint: [hint about what the change is]
model: haiku
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*)
---

Commit only the changes made in the current chat, including new files. Leave
pre-existing and unrelated changes untouched unless the user explicitly asks to
include them. Write the messages, run the commits, nothing else — no editing
files, no pushing, no amending, no rebasing.

Don't overthink this. The format below is mechanical; spend your attention on
the subject lines only.

## 1. Determine the scope

Use the conversation and the edits made during it to identify the exact paths
and hunks that belong to this chat. `git status` shows candidates, not automatic
permission to commit every change it lists.

- A bare `/commit`, "commit this", or equivalent means only this chat's changes.
- "Commit all", "commit everything", or an equally explicit instruction means
  every current working-tree change.
- If ownership of a path or hunk is uncertain, leave it uncommitted and report
  the uncertainty; do not guess.
- If a file mixes this chat's edits with unrelated edits, stage only this chat's
  hunks. Never stage the whole file merely because part of it is in scope.

## 2. Read the state

```
git status --porcelain
```

**If the index already has staged changes** (any line whose first column is not
a space or `?`), inspect whether the complete staged set is in scope. If it is,
do not run `git add`; make one commit from the index and stop. If it contains
anything outside the scope, do not alter or commit the user's staged set; stop
and report the conflict.

**If there are no changes at all** (empty output): commit nothing, say so, stop.

Otherwise continue.

## 3. Group the in-scope changes by component

Take only the in-scope paths and hunks identified in step 1. Include their
modifications (` M`, ` D`, ` T`, ` R`) and untracked files (`??`). Leave every
out-of-scope path and hunk untouched.

An untracked directory shows as a single `?? dir/` line — expand it with
`git status --porcelain --untracked-files=all` if you need the individual paths
to group them.

The component is the **first path segment**:

| Path                               | Component |
| ---------------------------------- | --------- |
| `nvim/lua/config/keymaps.lua`      | `nvim`    |
| `kitty/scripts/kitty-x.sh`         | `kitty`   |
| `systemd/user/adrop.service`       | `systemd` |
| `wiki/decisions.md`                | `wiki`    |
| `AGENTS.md`, `bootstrap.sh` (root) | `repo`    |

Two hard rules:

- `wiki/` is **always its own commit**, never mixed with code — required by
  [AGENTS.md](../../../AGENTS.md).
- Files at the repo root (no `/` in the path) group under `repo`.

## 4. Commit each group, one at a time

For each group, code components first and `wiki` last:

```
git add -- <paths in this group>
git --no-pager diff --cached -U1
git commit -m "<component>: <subject>"
```

Stage only that group's in-scope paths or hunks, so the index holds one group at
a time.

Read the diff before writing the message — the message describes what changed,
not which files changed. If a diff runs past ~400 lines, fall back to
`git --no-pager diff --cached --stat` and describe it at that level rather than
guessing at details you did not read.

You are running in the session that made these changes, so you may know _why_
they were made where the diff does not show it — use that. `$ARGUMENTS`, if
given, is the user's own hint about the change and outranks your reading of the
diff. Never invent a rationale you don't actually have; describing the change is
always better than a wrong reason.

## 5. Report

List the commits as `<short hash> <subject>` from `git log --oneline -<N>`.
Mention anything left uncommitted. Call out newly tracked files explicitly —
adding a file to the repo is a bigger deal than editing one.

## Message rules

Format: `component: subject`

- **English**, lowercase after the colon, **imperative mood** ("add", "fix",
  "drop" — not "added", "adds").
- **No trailing period.** No type prefixes (`feat:`, `chore:`) — the component
  is the prefix.
- Whole subject line **≤ 72 characters**.
- Say what changed and, where it fits, what for:
  `hypr: fix pixelated XWayland apps at fractional scale 1.6` beats
  `hypr: update config`.
- Banned as subjects: "update", "changes", "fixes", "formatted", "wip", "misc",
  and anything that just restates the filename.
- **Subject only.** Add a body only when there's a reason the subject cannot
  carry — then one blank line and at most two short lines.
- **Never** append `Co-Authored-By` or any "generated with" footer.

Good, from this repo's history:

```
nvim: dim inactive windows with Snacks.dim in zen mode
kitty: switch to JetBrainsMono Nerd Font Mono
darkman: fix laptop darkman toggling
hypr: convert indentation to tabs
wiki: document Snacks.dim in zen mode
```

## Never

- `git push`, `git commit --amend`, `git rebase`, `git reset --hard`,
  `git stash`
- `git add -A`, `git add .`, `git commit -a` — always stage explicit paths, so
  the index holds exactly one component's group at a time
- `git add -f` — a gitignored file stays ignored; if one genuinely belongs in
  the repo, say so and let the user fix `.gitignore`
- Editing any file, including the wiki. If a code change looks like it needs a
  wiki update, say so in the report; do not write it.
