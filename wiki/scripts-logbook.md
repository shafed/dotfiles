---
title: scripts-logbook
type: component
updated: 2026-09-06
covers:
  - scripts/generate_logbook.py
  - scripts/nvim-edit-handler.sh
---

# scripts — training logbook

Parent: [scripts](scripts.md). The editing side lives in [nvim](nvim.md); the
kitty session it opens into is in [sessions](sessions.md).

Markdown training sessions in `~/github/obsidian/training/` become a single generated
`logbook.html`, with a reverse link back into nvim for editing a session.

## generate_logbook.py

Generates a **single self-contained** `logbook.html` from the markdown sessions
in `~/github/obsidian/training/`. CSS+JS are inlined into the HTML, exercise
data is injected as JSON (`__EXDATA__`). Structure: parse sessions/events →
minimal markdown→HTML → render → assemble the page (`main`).

Key decisions (from git evolution):

- **Session filenames**: canonical session files use `YYYY-MM-DD-Training.md`. Legacy `YYYY-MM-DD-Day-N.md` files remain accepted for backward compatibility; new files should not encode weekly workout order in the filename.
- **Mood via session YAML frontmatter** (`mood: bad|mid|great`), not an inline
  tag in the body — commit "Add session-level mood via YAML frontmatter." Mood
  is a property of the whole session, so it lives in the file header; parsed by
  `MOOD_FM_RE`.
- **Search evolution**: fuzzy (`f49a39f`) → ranked (`832326c`, weighted
  `searchScore`: exact date match 10000, substring 8000, tokens 150/25/5) →
  speed up (`f9594b3`) → debounce (`48314a5`). ⚠️ Gotcha: `input` is debounced
  at **220ms** (`scheduleSearch`), and match highlighting (`highlight`, an
  expensive TreeWalker) is deferred and capped at the top 50 results
  (`scheduleHighlight`) — otherwise typing lags on a large feed.
- **`fuzzyToken` is per-word, not per-card**: `fuzzyMatch` (feed search) tests
  each query token against the individual words of a session (`row.words`),
  never against the whole card's text glued into one string. Matching against
  the glued blob let a short query subsequence-match almost any large card
  (digits/dates never share letters with a word query, but two unrelated
  _words_ concatenated can) — e.g. "bench" matched 145/241 sessions with only
  19 containing the literal word. Keep new fuzzy matching scoped to one word
  at a time.
- **Search box is shared state across both tabs**: `showView()` re-runs
  `runSearch`/`filterExercises` with the current `#search` value whenever you
  switch tabs, so a query typed in one tab is reflected in the other without
  retyping. ⚠️ Gotcha: `runSearch` must never call `showView('feed')` itself
  (it used to, as a belt-and-braces default) — since `showView` now calls
  `runSearch`, that becomes infinite recursion (`Maximum call stack size
exceeded`). Every caller of `runSearch` already guarantees the feed view is
  current before calling it.
- **Search vs. open exercise detail**: typing a new query while an exercise's
  history is open (`#exdetail` visible) goes through `exerciseListSearch()`,
  which closes the detail before filtering — otherwise the (correctly
  filtered) list updates invisibly behind the still-open detail card and
  looks like search did nothing. Tab-switch syncing (above) intentionally
  uses plain `filterExercises`/`runSearch` instead, so it does _not_ close an
  open detail — only an active new-search keystroke should navigate away.
- **Split dates in search** (`c26e2dc`): `2026 06` matches `2026-06-*`.
- **Exercise history** (`ce289e2`): clicking an exercise name → its history; the
  exercise list is sorted by last use, not alphabetically (`0a0133a`). The
  "← all exercises" back-link (inside `#exdetail`) is placed before the
  "Exercise history" `h2.eye` in the view markup, so it sits right under the
  search bar/tabs instead of below the section heading.
- `#search::-webkit-search-cancel-button` is disabled in CSS — Chromium-based
  mobile browsers (e.g. Samsung Internet) render their own native clear icon
  on `type="search"` inputs, which doubled up with the custom `.searchclear`
  button.
- **note-links / nvim-edit** (`fc30a5c`): in the feed and history — links
  `nvim-edit://<percent-encoded absolute path>` that open the session's source
  md file. Handled by `nvim-edit-handler.sh` (see below).
- **Events** (`training/events.md`): one event = `YYYY-MM-DD: #bad|#neutral|
#good text`. Prettier hard-wraps long lines, so `parse_events` treats a
  non-empty, non-heading continuation line as the previous event's next line:
  the break is kept (`\n`) and rendered as a visible `<br>` (WYSIWYG; a blank
  line ends the block). A line that starts like an event but has a bad date or
  unknown tag is warned about and skipped — never glued to the event above it.

## nvim-edit-handler.sh — the `nvim-edit://` handler

Handles `nvim-edit://` links from the logbook (see [nvim](nvim.md),
[sessions](sessions.md)). Opens the file in the kitty **obsidian** session as a
new nvim tab.

Design (a two-level fallback, because the kitty session and nvim are
asynchronous):

1. Via `kitty-zoxide-session.sh --named obsidian`, focuses/creates the obsidian
   session in the **main** (non-floating) kitty — not in transient panels like
   apps.sh.
2. Prefers `nvim --remote-tab` over the nvim socket
   (`$XDG_RUNTIME_DIR/nvim.<pid>.0`, the pid is searched with a ±5 delta since
   the exact nvim pid is unstable); on failure falls back to `kitty send-text`
   (`:tabedit` into a running nvim, or `nvim <file>` in a bare shell).

## Connections

- `nvim-edit-handler.sh` ↔ the kitty obsidian session and its nvim (see
  [sessions](sessions.md)).
- `generate_logbook.py` (generates links) ↔ `nvim-edit-handler.sh` (opens them).
