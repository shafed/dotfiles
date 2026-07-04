# AGENTS.md — dotfiles

Instructions for any AI agent (Claude Code, Codex, etc.) working in this repo.
Personal dotfiles: Arch Linux + Hyprland + kanata + kitty + nvim. Deployed via
manual symlinks `~/.config/<tool> → ~/dotfiles/<tool>` (no install script).

## Wiki-first: read before working

`wiki/` holds the knowledge base for these dotfiles, answering **"why it's built
this way"** (decisions, trade-offs, gotchas, links between components). It's the
"LLM Wiki" pattern by Andrej Karpathy — a persistent, compounding artifact the
agent reads before working and **maintains** after changes.

**At the start of any task that touches a config:**

1. Read [`wiki/index.md`](wiki/index.md) — the catalog of all pages.
2. Open the relevant page via its `covers:` field (which repo paths it
   describes).
3. Wiki conventions are in [`wiki/CONVENTIONS.md`](wiki/CONVENTIONS.md).

The wiki explains _why_, the code shows _how_. Don't duplicate code in the wiki;
record decisions.

## The agent must maintain the wiki (ingest / update / lint)

The wiki goes stale if it isn't kept up. The agent's job is to keep it in sync
with the code. The bookkeeping is on the agent, not the human.

### UPDATE — after changing a config

When you change a config's behavior (`kanata/config.kbd`, `hypr/`, `scripts/`,
`zsh/…`), in the **same** change:

- Find the page whose `covers:` includes the changed path and update it: record
  the new behavior and the **reason** (not just "what", but "why").
- Bump `updated:` in the frontmatter to today's date.
- If the change shifts status (🌱→🚧→✅), fix the row in `index.md`.
- If it touches several components (e.g. a hotkey), update the cross-cutting
  page too ([keymap](wiki/keymap.md), [sessions](wiki/sessions.md),
  [theming](wiki/theming.md)).
- A major/architectural decision or a rejected alternative → add an entry to
  [`wiki/decisions.md`](wiki/decisions.md).

The change history lives in git (`git log -- wiki/ <config>`); don't keep a
separate changelog file.

Wiki-only changes may be committed automatically, without asking for
confirmation first, as their **own separate commit** (don't bundle with code
changes even if edited in the same task). Prefix the commit message with
`wiki: `.

### INGEST — a new component/topic

When a new tool or major topic appears:

- Create a page per [CONVENTIONS.md](wiki/CONVENTIONS.md) (frontmatter +
  `covers:`).
- Add it to the right section of `index.md` with a status and one-line summary.
- Add backlinks to/from related pages (relative markdown links, e.g.
  `[keymap](keymap.md)`).

### LINT — periodic health check

When asked to "lint the wiki" (or on your own initiative, if you notice):

- **Contradictions** between a page and the current code (code is the source of
  truth).
- **Stale**: `covers:` paths that no longer exist; an old `updated:` while the
  covered code has clearly changed.
- **Orphaned** pages: no incoming links from index or other pages.
- **Broken links** and `covers:` entries that don't match real paths.
- **Unclosed stubs** (🌱) where the code is already stable — propose filling.
- Report what you found / fixed to the user.

## Division of responsibility

- **Human**: direction, which decisions matter, reviewing content.
- **Agent**: summarizing, backlinks, updating index/log, bookkeeping, surfacing
  contradictions and staleness.

## Misc

- Don't add `Co-Authored-By` lines to git commits.
- Links between wiki pages use relative markdown links, e.g.
  `[keymap](keymap.md)` (see CONVENTIONS.md).
- There are local `.claude/` dirs in `kanata/`, `scripts/`, `nvim/lua/config/` —
  these are scoped Claude Code permission settings, not to be confused with the
  wiki.
