---
title: global
type: topic
updated: 2026-09-26
covers:
  - instructions.md
  - .claude/skills/commit/SKILL.md
  - .claude/hooks/no-coauthor.sh
  - claude/settings.json
---

# Global — decisions outside the config components

This page collects **system-level** decisions that the component pages
(`kanata`, `hypr`, …) and `covers:` can't anchor to: the global agent
instructions and the home directory layout. The dotfiles wiki stays scoped to
configs; this page is the one place for "why the whole machine is set up this
way".

## Global agent instructions (`instructions.md`)

`instructions.md` at the repo root is the **single source** of what every CLI
agent loads in every project. `dots apply` symlinks it under the name each tool
expects: `~/.claude/CLAUDE.md`, `~/.config/opencode/AGENTS.md`,
`~/.codex/AGENTS.md`.

- **Why the source file is named `instructions.md`**: it lives inside this repo,
  and a file named `CLAUDE.md`/`AGENTS.md` there would be auto-loaded as
  _repo-scoped_ instructions on top of the global ones (Claude Code reads
  `CLAUDE.md` in subdirectories; opencode/Codex read `AGENTS.md`). A neutral
  name avoids duplication. What each tool reads is set by the **symlink name**,
  not the source name.
- **It is now a single rule, not a ruleset** (2026-08-14): the file used to
  carry ~70 lines of general coding rules and this repo's `CLAUDE.md` another
  ~103. Both were deleted in `1add5fc`; a Context7 MCP block that briefly
  replaced them was cut too, because the Context7 server already injects that
  guidance itself and the rest of it was step-by-step tool-use instruction — the
  category Anthropic removed wholesale for Opus 5. What remains is one line: no
  `Co-Authored-By`. Rationale for cutting rather than growing these files —
  [decisions](decisions.md).
- Anything that does survive here is loaded into context in **every session of
  every project**, so the bar for adding a line is high.
- ⚠️ **Do not add verification instructions** — "double-check your work", "add a
  final verification step", "use a subagent to verify". Anthropic's Opus 5
  prompting guide calls these out by name: the model already self-verifies, and
  the instruction compounds with that behavior into over-verification, burning
  tokens with no quality gain. Same for "be conservative / only report important
  findings" in a review prompt — Opus 5 follows it literally and reports less.
  Ask for everything and filter in a second pass instead.

All three symlinks and the hook script are in place again as of 2026-08-14, and
`instructions.md` is tracked once more. The registration that used to be missing
lives in the tracked [../claude/settings.json](../claude/settings.json), which
`base.toml` links to `~/.claude/settings.json` — see below for why a link is
safe after all.

### The one rule that was also enforced, not just stated

Of the old rules only **no `Co-Authored-By`** was mechanically checkable, so it
got a second, hard layer:
[../.claude/hooks/no-coauthor.sh](../.claude/hooks/no-coauthor.sh) denies any
`git commit` whose message carries an attribution footer. `base.toml` links it
to `~/.claude/hooks/` and the tracked `claude/settings.json` registers it, so
`dots apply` delivers the guard whole instead of only half of it.

- **Why a hook and not just the sentence**: prose competes for attention and
  loses it on a long task. Which rules earn this treatment —
  [decisions](decisions.md#recorded).
- **Why it belongs in `~/.claude/settings.json`, not the repo's**: the rule is
  global, so registering it repo-side would both under-cover (other projects)
  and double-fire here.
- **`~/.claude/settings.json` is a symlink** to
  [../claude/settings.json](../claude/settings.json) (2026-09-26). Claude Code
  writes this file itself when a `/config` option stored in user settings
  changes, such as the theme, and an earlier version of this page assumed that
  write would clobber a link, so a `claude-user-hooks` generator merged the
  hook registrations into a real file instead. That assumption was tested and
  is wrong: with `CLAUDE_CONFIG_DIR` pointing at a directory whose
  `settings.json` was a symlink, Claude Code 2.1.283 wrote `"theme": "light"`
  from the first-run theme picker **through** the link, and the link survived.
  The generator was removed; hooks are now registered in the tracked file.
  Re-run that probe after a major Claude Code update.
- ⚠️ **Gotcha**: since the file is tracked, whatever Claude Code writes into it —
  a theme switch, an "always allow" rule — shows up as a diff in this **public**
  repo. Read `git diff claude/settings.json` before committing it; one-off
  permission approvals (tool paths, local ports) do not belong here. (Plugins,
  MCP servers and the global config keys live in a _different_ file,
  `~/.claude.json`, which stays untracked.)
- ⚠️ **Gotcha**: `claude/` at the repo root, not `.claude/`. `.claude/` is this
  repo's own project config; linking the user settings to
  `.claude/settings.json` would load the same hooks twice in every session
  started here.
- The guard only sees an agent's `Bash` calls. A commit typed directly in a
  terminal bypasses it — which is the escape hatch if a human co-author ever
  genuinely needs crediting.

## Commit convention and the `/commit` skill

- Commit subjects in this repo are `component: subject` — the component is the
  **first path segment** of what changed (`nvim/lua/config/keymaps.lua` →
  `nvim`; root files → `repo`). English, imperative, ≤ 72 chars, no
  `feat:`/`chore:` type prefixes. Rationale and the full rules live in the skill
  itself:
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
  Claude Code and opencode read `.claude/skills/`, Codex reads
  `.agents/skills/`. Those are two copies of the same procedure with different
  frontmatter — see [bootstrap](bootstrap.md) for why, and for the gotcha about
  editing both.

⚠️ **Gotcha**: the skill is untracked-blind by design, so it cannot commit
itself, or any other new file. First-time additions need a manual `git add`.

## Home directory layout

Restructure done (2026-08-02).

- `~/github/obsidian/` — notes vault.
- `~/github/dotfiles/` — this repo.
- `~/github/` — home for all other git repos.
- `~/projects` — renamed to `study/` under `~/github/`.
