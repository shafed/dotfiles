---
name: commit
description:
  "Commit work in this dotfiles repo the house way: only the current chat's
  changes, one commit per top-level component with `scope: description`, `wiki/`
  always committed on its own, never mixed with code. Use whenever the user runs
  /commit, says 'commit this', 'закоммить', 'сделай коммит', 'зафиксируй
  изменения', or otherwise asks for work here to be committed — including when
  they say nothing about message format or the wiki split, since getting those
  two right is the whole point of this skill."
user-invocable: true
argument-hint: [optional hint about what the change was for]
model: sonnet
effort: medium
allowed-tools:
  Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*),
  Bash(git log:*)
---
- commit like `scope: description`
- `wiki/` is committed alone
