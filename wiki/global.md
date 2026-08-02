---
title: global
type: topic
updated: 2026-08-02
covers:
  - instructions.md
---

# Global — decisions outside the config components

This page collects **system-level** decisions that the component pages
(`kanata`, `hypr`, …) and `covers:` can't anchor to: the global agent
instructions and the home directory layout. The dotfiles wiki stays scoped to
configs; this page is the one place for "why the whole machine is set up this
way".

## Global agent instructions (`instructions.md`)

- `instructions.md` at the repo root is the **single source** of the general
  coding rules loaded by every CLI agent (think-before-coding, simplicity,
  surgical changes, goal-driven execution, no `Co-Authored-By`).
- It is symlinked by `bootstrap.sh` to all three agents: `~/.claude/CLAUDE.md`,
  `~/.config/opencode/AGENTS.md`, `~/.codex/AGENTS.md`.
- **Why the source file is named `instructions.md`**: it lives inside this repo,
  and a file named `CLAUDE.md`/`AGENTS.md` there would be auto-loaded as
  _repo-scoped_ instructions on top of the global ones (Claude Code reads
  `CLAUDE.md` in subdirectories; opencode/Codex read `AGENTS.md`). A neutral
  name avoids duplication. What each tool reads is set by the **symlink name**,
  not the source name.
- Kept deliberately small (a handful of rules) — it's loaded into context in
  every session of every project.

## Home directory layout

✅ Restructure done (2026-08-02).

- `~/obsidian/` — notes vault.
- `~/dotfiles/` — this repo.
- `~/github/` — home for all other git repos.
- `~/projects` — renamed to `study/` under `~/github/`.
