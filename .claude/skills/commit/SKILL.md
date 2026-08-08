---
name: commit
description: Commit the current tracked changes in this dotfiles repo with unified `component: subject` messages, split one commit per top-level component. Use when the user runs /commit, says "commit this", "закоммить", or asks to commit the work in this repo.
user-invocable: true
argument-hint: [hint about what the change is]
model: haiku
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*)
---

Commit the tracked changes in this repo. Write the messages, run the commits,
nothing else — no editing files, no pushing, no amending, no rebasing.

Don't overthink this. The format below is mechanical; spend your attention on
the subject lines only.

**Repo guard.** The taxonomy below assumes this repo's flat layout — one
top-level directory per tool. It is wrong anywhere else, where a first path
segment is `src/` or `lib/`. Codex has no project-scoped skills and so offers
this one everywhere: if `git rev-parse --show-toplevel` is not the dotfiles
repo, stop and say the convention doesn't apply here.

## 1. Read the state

```
git status --porcelain
```

**If the index already has staged changes** (any line whose first column is not
a space or `?`): the user staged those deliberately. Do not run `git add`. Make
**one** commit from the index and stop. Say that you committed the pre-staged
set only and left the rest.

**If there are no tracked modifications** (only `??` lines, or nothing): commit
nothing, say so, stop.

Otherwise continue.

## 2. Group the changed paths by component

Take only the tracked-modified paths — lines starting with ` M`, ` D`, ` T`,
` R`. **Ignore `??` untracked lines entirely**; never stage new files.

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

## 3. Commit each group, one at a time

For each group, code components first and `wiki` last:

```
git add -u -- <paths in this group>
git --no-pager diff --cached -U1
git commit -m "<component>: <subject>"
```

Stage only that group's paths, so the index holds one group at a time.

Read the diff before writing the message — the message describes what changed,
not which files changed. If a diff runs past ~400 lines, fall back to
`git --no-pager diff --cached --stat` and describe it at that level rather than
guessing at details you did not read.

You are running in the session that made these changes, so you may know _why_
they were made where the diff does not show it — use that. `$ARGUMENTS`, if
given, is the user's own hint about the change and outranks your reading of the
diff. Never invent a rationale you don't actually have; describing the change is
always better than a wrong reason.

## 4. Report

List the commits as `<short hash> <subject>` from `git log --oneline -<N>`.
Mention anything left uncommitted, untracked files included.

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
- `git add -A`, `git add .`, `git commit -a` — untracked files stay untracked
- Editing any file, including the wiki. If a code change looks like it needs a
  wiki update, say so in the report; do not write it.
