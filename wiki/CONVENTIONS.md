# Wiki conventions (schema)

This wiki is a knowledge base for the dotfiles, optimized for reading by an
**LLM agent** (Claude Code), not just a human. The main value of the pages is to
answer the question **"why is it done this way"** (rationale/decisions), not to
retell the code, which the agent can already read on its own.

## What kind of pattern this is

Built after Andrej Karpathy's "LLM Wiki"
(https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f): a
persistent, compounding collection of markdown pages that the agent reads before
working and **updates** after config changes. The wiki is not a snapshot of the
code, but a knowledge layer on top of it: decisions, trade-offs, gotchas,
connections between components.

## Layers

- **Code** (`../hypr`, `../kanata`, `../scripts`, …) — the source of truth for
  _how_ everything works. The agent reads it directly. The wiki does **not**
  duplicate it.
- **`wiki/`** — the knowledge layer: _why_ it's this way, what alternatives were
  rejected, where the gotchas are, how components connect. Maintained entirely
  with the agent's involvement.
- **`index.md`** — a catalog of all pages with links and one-line summaries.
- **`log.md`** — an append-only log of ingest/update/lint operations (see
  AGENTS.md).

## Page naming

- One page = one component or one cross-cutting topic.
- File name in `kebab-case.md`, matching the `title` in frontmatter.
- Component pages are named after the repo folder: `kanata.md`, `hypr.md`,
  `scripts.md`, `kitty.md`, `nvim.md`, `zsh.md`.
- Cross-cutting topics — by task: `keymap.md`, `bootstrap.md`, `theming.md`,
  `decisions.md`, `sessions.md`.

## Frontmatter

Minimal YAML at the top of each page:

```yaml
---
title: kanata
type: component # component | topic | index
updated: 2026-07-01 # ISO date of the last substantive change
covers: # which repo paths the page describes
  - kanata/config.kbd
---
```

Don't turn frontmatter into a database. `covers` matters: it lets the agent find
the page that needs updating when editing a file.

## Text style (LLM-friendly)

- Write as if the page is read by an agent **with no other context**: explicit
  headings, self-contained paragraphs, minimal "as mentioned above".
- Keep pages small and self-contained — so they fit in context whole.
- Record **decisions and their reasons**, not code behavior. Bad: "bind = SUPER,
  Q, killactive". Good: "killactive on Super+Q, because Q is under the thumb in
  kanata's apps layer; see [[keymap]]".
- Mark **gotchas** with the explicit `⚠️ Gotcha:` marker.
- Links between wiki pages are **`[[wikilinks]]`** by page name without an
  extension: `[[keymap]]`, `[[scripts]]`. This is the primary and only style for
  internal links (Obsidian resolves them natively). We don't use markdown links
  `[text](page.md)` for internal connections.
- Exception — links **outside** `wiki/` (e.g. the root `AGENTS.md`): keep as a
  relative markdown link `[../AGENTS.md](../AGENTS.md)`, since `[[...]]` only
  searches within the wiki vault folder.
- Links to code — relative from the repo root: `../kanata/config.kbd`.

## Categories for index.md

- **Setup** — how to deploy/maintain (bootstrap, deploy symlinks).
- **Components** — one page per tool.
- **Cross-cutting** — cross-cutting topics (keymap, theming, sessions).
- **Decisions** — major architectural decisions and rejected alternatives.
