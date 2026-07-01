# CLAUDE.md

The main instructions for this repo are in [`AGENTS.md`](AGENTS.md) (the shared
file for all AI agents: Claude Code, Codex, etc.). **Read it.** Key point: before
working on a config, read `wiki/index.md` and maintain the wiki
(ingest/update/lint).

Claude-specific:

- Don't add `Co-Authored-By: Claude` to git commits.
- Scoped Claude Code permission settings live in local `.claude/` dirs inside
  `kanata/`, `scripts/`, `nvim/lua/config/`.
