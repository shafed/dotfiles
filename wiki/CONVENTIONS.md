---
title: CONVENTIONS
type: index
updated: 2026-08-14
---

# Wiki conventions (schema)

Written to be read by an **LLM agent**, not just a human.

The code (`../hypr`, `../kanata`, `../scripts`, …) is the source of truth for
_how_ things work, and the agent reads it directly. So a page earns its keep
only by carrying what the code cannot: **why it's this way**, what was rejected,
and where the traps are. Before writing a line, ask whether an agent could
recover it by opening the config. If yes, don't write it.

Change history is `git log -- wiki/`. Never add a changelog page.

## Page naming

- One page = one component or one cross-cutting topic. Component pages take the
  repo folder's name; topic pages are named by task.
- A page that outgrows a single context window may split into sub-pages, with
  the original becoming a map of content that links to them. Sub-pages are
  prefixed with their parent: `scripts-pickers.md`, `nvim-editing.md`.
- File name in `kebab-case.md`, matching the `title` in frontmatter. The two
  meta pages — `index.md` and this file — are the exception; `CONVENTIONS.md`
  stays uppercase so the two files that describe the wiki sort apart from the
  pages that are the wiki. Don't "fix" it by renaming.

## Frontmatter

```yaml
---
title: kanata
type: component # component | topic | moc | index
updated: 2026-07-01 # ISO date of the last substantive change
covers: # which repo paths the page describes
  - kanata/config.kbd
---
```

`covers` is the one field that does work: it's how the agent finds which page to
update when it edits a file. Keep the rest minimal — this is not a database.

`type: moc` marks a page that **routes rather than answers**: it has sub-pages
and its body is a map of them. Read it expecting to open something else next,
and when recording a new fact, put it on the sub-page — a MoC only carries what
spans siblings. `index` stays reserved for the two meta pages that describe the
wiki itself (`index.md`, this file); `index.md` is a map too, but it is the root
one, not a component that grew sub-pages.

## Text style

- Assume the reader has **no other context**: explicit headings, self-contained
  paragraphs, no "as mentioned above".
- Keep a page small enough to fit in context whole. When it stops fitting, split
  it (see above) rather than letting it sprawl.
- Record **decisions and their reasons**, not code behavior:
  - Bad: "bind = SUPER, Q, killactive"
  - Good: "killactive on Super+Q, because Q is under the thumb in kanata's apps
    layer; see [keymap](keymap.md)"
- Mark traps with an explicit `⚠️ Gotcha:` and state the **consequence** — what
  breaks, and how it looks when it does. A warning with no failure mode is not
  actionable.
- Internal links are relative markdown: `[keymap](keymap.md)`. Not
  `[[wikilinks]]` — GitHub and most renderers show those as literal text, while
  Obsidian resolves markdown links fine. Same style for links out of `wiki/` and
  into code: `[../AGENTS.md](../AGENTS.md)`, `../kanata/config.kbd`.
