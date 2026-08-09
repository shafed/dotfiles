---
title: global
type: topic
updated: 2026-08-09
covers:
  - instructions.md
  - .claude/skills/commit/SKILL.md
  - .claude/hooks/no-coauthor.sh
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

### The one rule that is also enforced, not just stated

Of those rules only **no `Co-Authored-By`** is mechanically checkable, so it has
a second, hard layer:
[../.claude/hooks/no-coauthor.sh](../.claude/hooks/no-coauthor.sh) denies any
`git commit` whose message carries an attribution footer. It is registered in
`~/.claude/settings.json` (not the repo's), because the rule it enforces is
global; `bootstrap.sh` links the script into `~/.claude/hooks/`.

- **Why a hook and not just the sentence**: prose competes for attention and
  loses it on a long task. Which rules earn this treatment, and why the sentence
  stays in `instructions.md` anyway — [decisions](decisions.md#recorded).
- ⚠️ **Gotcha**: the `hooks` block in `~/.claude/settings.json` is **not tracked
  by this repo** — that file holds machine state (plugins, marketplaces) and is
  a real file, not a symlink. `bootstrap.sh` restores the script but not its
  registration; on a fresh machine the block has to be re-added by hand.
- The guard only sees an agent's `Bash` calls. A commit typed directly in a
  terminal bypasses it — which is the escape hatch if a human co-author ever
  genuinely needs crediting.

## Commit convention and the `/commit` skill

- Commit subjects in this repo are `component: subject` — the component is the
  **first path segment** of what changed (`nvim/lua/config/keymaps.lua` → `nvim`;
  root files → `repo`). English, imperative, ≤ 72 chars, no `feat:`/`chore:`
  type prefixes. Rationale and the full rules live in the skill itself:
  [../.claude/skills/commit/SKILL.md](../.claude/skills/commit/SKILL.md).
- `/commit` splits the working tree **one commit per component**, `wiki/` always
  separate — which is how the [AGENTS.md](../AGENTS.md) "wiki commits are their
  own commit" rule gets enforced mechanically instead of by memory.
- It only ever runs `git add -u -- <paths>`, so untracked files stay untracked
  and never ride along.
- It declares `model: haiku` in its frontmatter. In a skill that is a **turn-
  scoped model switch, not a subagent** — only `context: fork` forks. So the
  cheap model still sees the session that produced the changes and can say _why_
  they were made. Why that beats Conventional Commits and a real subagent —
  [decisions](decisions.md).

- All three CLI agents pick it up, and it stays project-scoped in all three:
  Claude Code and opencode read `.claude/skills/`, Codex reads `.agents/skills/`.
  Those are two copies of the same procedure with different frontmatter — see
  [bootstrap](bootstrap.md) for why, and for the gotcha about editing both.

⚠️ **Gotcha**: the skill is untracked-blind by design, so it cannot commit
itself, or any other new file. First-time additions need a manual `git add`.

## Home directory layout

✅ Restructure done (2026-08-02).

- `~/obsidian/` — notes vault.
- `~/dotfiles/` — this repo.
- `~/github/` — home for all other git repos.
- `~/projects` — renamed to `study/` under `~/github/`.
