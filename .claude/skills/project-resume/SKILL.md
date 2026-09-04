---
name: project-resume
description: "Recover the real working state of a git project before continuing work. Use when the user asks to resume/continue a project, asks what is left or what changed, or when entering an existing repo whose current state should not be reconstructed from scratch. Start with the bundled snapshot script, then read only the state/guidance files and code relevant to the current task."
user-invocable: true
argument-hint: [optional task or area to resume]
---

1. From the repository root, run `bash .claude/skills/project-resume/scripts/snapshot.sh` (or this skill's resolved script path if installed globally).
2. Treat the snapshot as an index, not as project truth. Read repository guidance (`CLAUDE.md` / `AGENTS.md`) and the detected state file before exploring the tree.
3. If commits exist after the last state-file update, reconcile the state file with those commits and changed paths. Say when the state document appears stale.
4. Read only the specification, architecture, plan, tests, and source files needed for the user's current task. Do not reread large documents merely to rebuild context already represented by the state file.
5. Do not modify files, run destructive commands, or start implementation unless the user's request requires it.
6. When reporting the recovered state, distinguish facts from the repository from your inference, and end with the concrete next work item when one is identifiable.
