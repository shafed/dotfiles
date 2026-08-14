---
title: global
type: topic
updated: 2026-08-14
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

`instructions.md` at the repo root is the **single source** of what every CLI
agent loads in every project. `bootstrap.sh` symlinks it under the name each
tool expects: `~/.claude/CLAUDE.md`, `~/.config/opencode/AGENTS.md`,
`~/.codex/AGENTS.md`.

- **Why the source file is named `instructions.md`**: it lives inside this repo,
  and a file named `CLAUDE.md`/`AGENTS.md` there would be auto-loaded as
  _repo-scoped_ instructions on top of the global ones (Claude Code reads
  `CLAUDE.md` in subdirectories; opencode/Codex read `AGENTS.md`). A neutral
  name avoids duplication. What each tool reads is set by the **symlink name**,
  not the source name.
- **It is now one block, not a ruleset** (2026-08-14, `1add5fc`): the file used
  to carry ~70 lines of general coding rules (think-before-coding, simplicity,
  surgical changes, goal-driven execution, no `Co-Authored-By`), and this repo's
  `CLAUDE.md` carried another ~103. Both were deleted the same day; what remains
  in `instructions.md` is the Context7 MCP block. Rationale for cutting rather
  than growing these files — [decisions](decisions.md).
- Anything that does survive here is loaded into context in **every session of
  every project**, so the bar for adding a line is high.
- ⚠️ **Do not add verification instructions** — "double-check your work", "add a
  final verification step", "use a subagent to verify". Anthropic's Opus 5
  prompting guide calls these out by name: the model already self-verifies, and
  the instruction compounds with that behavior into over-verification, burning
  tokens with no quality gain. Same for "be conservative / only report important
  findings" in a review prompt — Opus 5 follows it literally and reports less.
  Ask for everything and filter in a second pass instead.

⚠️ **Gotcha — current state on this machine does not match `bootstrap.sh`**
(verified 2026-08-14):

| Link                                        | State                          |
| ------------------------------------------- | ------------------------------ |
| `~/.codex/AGENTS.md`                        | live symlink                   |
| `~/.config/opencode/AGENTS.md`              | live symlink                   |
| `~/.claude/CLAUDE.md`                       | **missing** — Claude Code gets no global instructions |
| `~/.claude/hooks/no-coauthor.sh`            | **missing**                    |
| `no-coauthor` entry in `~/.claude/settings.json` | **absent** — the guard never fires |

`instructions.md` itself is **untracked** since `1add5fc` deleted it, so
`bootstrap.sh` on a fresh clone would link three names at a file that isn't
there. Re-running `bootstrap.sh` restores the three symlinks but never the
`settings.json` registration (see below).

### The one rule that was also enforced, not just stated

Of the old rules only **no `Co-Authored-By`** was mechanically checkable, so it
got a second, hard layer:
[../.claude/hooks/no-coauthor.sh](../.claude/hooks/no-coauthor.sh) denies any
`git commit` whose message carries an attribution footer. The script still
exists in the repo; it is currently unlinked and unregistered (table above), so
nothing enforces it right now.

- **Why a hook and not just the sentence**: prose competes for attention and
  loses it on a long task. Which rules earn this treatment —
  [decisions](decisions.md#recorded).
- **Why it belongs in `~/.claude/settings.json`, not the repo's**: the rule is
  global, so registering it repo-side would both under-cover (other projects)
  and double-fire here.
- ⚠️ **Gotcha**: the `hooks` block in `~/.claude/settings.json` is **not tracked
  by this repo** — that file holds machine state (plugins, marketplaces) and is
  a real file, not a symlink. `bootstrap.sh` restores the script but not its
  registration; on a fresh machine the block has to be re-added by hand. This is
  exactly how it went missing here.
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

Restructure done (2026-08-02).

- `~/obsidian/` — notes vault.
- `~/dotfiles/` — this repo.
- `~/github/` — home for all other git repos.
- `~/projects` — renamed to `study/` under `~/github/`.
