---
title: cli-agents
type: topic
updated: 2026-08-14
covers:
  - instructions.md
  - AGENTS.md
  - .claude/skills
  - .agents/skills
  - .claude/settings.json
---

# Sharing config across CLI agents

Three CLI agents run here: **Claude Code**, **Codex**, **opencode**. They
configure the same things (instructions, skills, hooks, MCP) and read them from
different paths. This page is the general rule and the verified discovery table;
the concrete wiring of this repo lives in [bootstrap](bootstrap.md), and the
sources it wires in [global](global.md).

## The rule

**One real file per concept.** Prefer a symlink over a copy — a copy rots
silently, a symlink can't. Keep a second copy only when a format actually
differs, and when it does, say why in the wiki (as `bootstrap.md` does for the
`/commit` skill's `model: haiku`).

Where the formats differ structurally (TOML vs JSON), share the **payload** —
the script, the markdown — and duplicate only the few lines of **wiring**.

## What each agent reads (verified 2026-08-08 · Claude Code 2.1.226 · Codex 0.147.0)

| Thing           | Claude Code                       | Codex                                          | Can it be one file?                      |
| --------------- | --------------------------------- | ---------------------------------------------- | ---------------------------------------- |
| Global rules    | `~/.claude/CLAUDE.md`             | `~/.codex/AGENTS.md`                           | ✅ symlink — `instructions.md`; the Claude Code link is currently missing, see [global](global.md) |
| Repo rules      | `./CLAUDE.md`                     | `./AGENTS.md`                                  | ✅ symlink — done, tracked in git        |
| Skills (repo)   | `./.claude/skills/<n>/SKILL.md`   | `./.agents/skills/`, `./.codex/skills/`        | ⚠️ path differs; body portable           |
| Skills (global) | `~/.claude/skills/`               | `~/.codex/skills/`, `~/.agents/skills/`        | ⚠️ same, at `$HOME` scope                |
| Hooks           | `.claude/settings.json` → `hooks` | `.codex/hooks.json` or `.codex/config.toml`    | ➗ share the script, re-declare the hook |
| MCP servers     | `.mcp.json` / `~/.claude.json`    | `~/.codex/config.toml` `[mcp_servers]`         | ❌ JSON vs TOML                          |
| Permissions     | `settings.json` `permissions`     | `config.toml` `approval_policy`/`sandbox_mode` | ❌ different security models             |

Claude Code reads **only** `.claude/skills/`; Codex reads **only** its own two.
Neither looks into the other's directory, so a repo-level skill needs a second
path either way — symlink if the frontmatter is identical, copy if it isn't.

Hook **events** line up almost exactly (`PreToolUse`, `PostToolUse`,
`SessionStart`, `UserPromptSubmit`, `Stop`, …) and both pass JSON on stdin and
read JSON on stdout, so a hook script such as
[../.claude/hooks/wiki-reminder.sh](../.claude/hooks/wiki-reminder.sh) runs
unmodified under either — only the block that registers it is per-agent.

Three hooks exist, and they split by **scope**, not by agent.
`.claude/settings.json` registers the two repo-scoped ones on `PostToolUse`
(`wiki-reminder.sh`, `wiki-date.sh`); `no-coauthor.sh` enforces a rule from
`instructions.md` that holds in every project, so it is registered globally in
`~/.claude/settings.json` instead — see [global](global.md).

All three are plain scripts and would port to Codex unmodified; only the
registration block is per-agent, and so far only Claude Code has one. That is
why the rules they enforce must **stay written down** in `instructions.md` and
`CLAUDE.md` — for Codex and opencode the prose is still the only copy. See
[decisions](decisions.md#recorded).

⚠️ **Gotcha**: Claude Code has no `AGENTS.md` fallback, in any version. It reads
`AGENTS.md` only through a symlink or an `@AGENTS.md` import on the first line
of `CLAUDE.md`. Use the import form on Windows, where symlinks need admin
rights.

## How to re-verify after a CLI update

Discovery paths move between releases — Codex gained repo-level skill discovery
only after the `/commit` skill was first wired globally into `~/.codex/skills/`.
Don't trust docs or blog posts; probe the installed binary:

```sh
mkdir -p /tmp/probe/.agents/skills/probe-repo
printf -- '---\nname: probe-repo\ndescription: probe\n---\nDo nothing.\n' \
  > /tmp/probe/.agents/skills/probe-repo/SKILL.md
cd /tmp/probe && codex exec --skip-git-repo-check \
  "List the names of every skill available to you. Do not run any of them." </dev/null
```

A candidate directory that shows up in the listing is discovered; one that
doesn't, isn't. Each tool also has a cheaper first-line check —
`codex debug prompt-input`, `opencode debug skill` — see
[bootstrap](bootstrap.md). The same trick answers "does it load this
instructions file": put a distinctive sentence in the candidate file and ask the
agent to repeat it.

## Deliberately not unified

- **MCP servers** — TOML on one side, JSON on the other, and the server sets
  differ in practice. A generator would add more moving parts than the
  duplication it removes.
- **Permissions / sandbox** — Claude's allow/deny rules and Codex's
  `approval_policy` + `sandbox_mode` are different security models, not two
  encodings of one policy. Writing them separately is the honest option.
