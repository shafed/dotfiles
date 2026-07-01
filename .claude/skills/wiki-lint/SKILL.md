---
name: wiki-lint
description: Run a LINT health-check over this dotfiles wiki/ — find drift between pages and code, broken [[wikilinks]], stale covers:, orphaned and stub pages. Use when the user asks to check/heal the wiki or runs /wiki-lint.
---

# wiki-lint

Health-check for the `wiki/` knowledge base in this dotfiles repo. Procedure is
the LINT section of `AGENTS.md`. Code is the source of truth; the wiki bends to
the code, not the other way around.

## What to check

Sweep all `wiki/*.md`. For each finding, give `wiki/<file>:<line>` and a one-line
summary.

1. **Broken `[[wikilinks]]`** — every `[[target]]` must resolve to
   `wiki/target.md`. Exception: the word `[[wikilinks]]` in prose is not a link.
   ```
   grep -rhoE '\[\[[a-zA-Z0-9-]+\]\]' wiki/ | sed -E 's/\[\[|\]\]//g' | sort -u \
     | while read t; do [ -f "wiki/$t.md" ] || echo "BROKEN: [[$t]]"; done
   ```

2. **Internal markdown links** — there should be none (style is `[[wikilinks]]`).
   The only legal markdown link is the external `../AGENTS.md`.
   ```
   grep -rn '](.*\.md)' wiki/ | grep -v '\.\./' | grep -v 'CONVENTIONS.md:.*page.md'
   ```

3. **Stale / broken `covers:`** — every path listed in a page's `covers:` must
   still exist in the repo. Paths that are gone → the page documents deleted code.
   ```
   grep -rn 'covers:' -A6 wiki/   # then check each path: test -e <path>
   ```

4. **Page ↔ code contradictions** — spot-check key claims against current code,
   especially where `updated:` is old but `git log` shows recent changes to a
   covered file. Do not rewrite code — record the discrepancy.
   ```
   git -C . log --oneline -5 -- <covered-path>
   ```

5. **Orphaned pages** — a page with no incoming `[[link]]` from `index.md` or any
   other page (ignore `index` / `CONVENTIONS` / `log` themselves).

6. **Stubs over stable code** — pages still marked 🌱 (or with empty sections)
   whose covered code hasn't changed in a while → candidates to flesh out.

## How to report

- Group findings by type (1–6); each as `wiki/<file>:<line>` + summary.
- Don't fix anything silently. Small unambiguous fixes (a broken link, a
  vanished `covers:` path) — propose them, and apply only if the user confirms
  or asked to "heal"; anything judgemental (contradictions, filling stubs) —
  just list.
- If you fixed anything, bump `updated:` on the touched pages and append a line
  to `wiki/log.md` with a `LINT` prefix (what you found / fixed).
- If everything is clean, say so in one line and add no log entry.
