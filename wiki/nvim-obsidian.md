---
title: nvim-obsidian
type: component
updated: 2026-09-03
covers:
  - nvim/lua/utils/obsidian.lua
  - nvim/lua/utils/review.lua
  - nvim/snippets/
  - nvim/spell/
---

# nvim — obsidian vault, logbook, snippets

Parent: [nvim](nvim.md). Generation and viewing of the logbook itself is in
[scripts-logbook](scripts-logbook.md).

## Integration with the training logbook

nvim is the editing side of the training logbook; generation and viewing are in
[scripts](scripts.md), invocation from the editor is in [sessions](sessions.md).

- `<leader>lr` regenerates `logbook.html` and `<leader>lp`
  (`obsidian.save_training_note`) regenerates it automatically after saving a
  note. Both funnel through one shared helper — `obsidian.regenerate_logbook()`.
  (They used to be two separate copies of the script invocation with divergent
  error handling: `<leader>lr` checked the script existed and reported output,
  while `save_training_note` ran it silently with no existence guard. Merged
  into a single guarded runner that takes `{ silent = true }` for the
  auto-trigger.)
- `<leader>lp` saves the buffer as
  `~/github/obsidian/training/Full Body <текущий год>/YYYY-MM-DD-Training.md` and
  rewrites the first H1, when present, to `YYYY-MM-DD-Training`. The filename no
  longer depends on a `Day N`/H1 value. It prompts for the session date
  (`vim.ui.input`, defaults to today, validated as `YYYY-MM-DD`) so a session
  logged late can be dated to when the workout actually happened. The logbook
  parser accepts the current `YYYY-MM-DD-Training` form and legacy
  `YYYY-MM-DD-Day-N` files, so old sessions remain readable.
- A separate keymap opens `logbook.html` via `xdg-open`.
- `obsidian.push_with_cooldown()` — auto commit+push of the `~/github/obsidian` vault
  (an hour cooldown) so note edits get backed up without manual commits.
- `nvim-edit-handler.sh` in [scripts](scripts.md) — the reverse link: the
  logbook opens a note for editing in nvim.

## Periodic review of daily notes

`lua/utils/review.lua` turns daily notes into temporary read-only markdown
buffers so reviews happen inside the editor without creating another generated
artifact in the vault:

- `<leader>lw` reviews the previous 7 days and `<leader>lm` the previous 30;
  `:Review [days]` provides an arbitrary window.
- `<leader>ld` collects the same calendar day from earlier years.
- Untouched template notes are omitted, and YAML/meta-bind boilerplate is
  stripped so the combined buffer emphasizes what was actually written.
- Month-sized reviews also summarize the most-edited markdown files from the
  vault's git history. The vault is already auto-committed, so git provides a
  useful attention signal without adding review metadata to notes.

There is deliberately no yearly shortcut: flattening 365 daily notes into one
buffer is not a useful reading surface, while `:Review [days]` still permits
deliberate longer windows. Daily paths follow the vault's English `strftime`
naming convention under `journal/YYYY/YYYY-MM-DD-Weekday.md`.

⚠️ Gotcha: LazyVim core binds `<leader>l` directly to `:Lazy` (exact match, not
a which-key group), which silently swallowed the `[P]Log` keys
(`lc`/`lp`/`lv`/`lr`) above — the which-key `group` registration alone doesn't
override it. Fixed in `keymaps.lua` by `vim.keymap.del("n", "<leader>l")` and
remapping `:Lazy` to `<leader>L`.

⚠️ Gotcha: `harper_ls` (grammar checking) is **disabled on training notes** —
`excludePatterns` contains `~/github/obsidian/training/**/*.md` and `Day [123].md`.
Reason: training notes are tables/abbreviations, and harper chokes on false
positives. Commit `ef70575` ("recursive disable harper in training").

## Snippets and spell

- `snippets/` — LuaSnip snippets. Markdown vault templates live in
  `markdown.lua`; LaTeX snippets live in `tex/*.lua` and `bib.lua`.
- Vault note triggers are `;source`, `;project`, `;category`, `;meta`,
  `;creator`, `;quote`, and `;daily`. The daily snippet derives its heading from
  the filename and adds no metadata.
- There's a `;date` snippet — inserts the current date in ISO format (commit
  `2e4f335`).
- LuaSnip **choice nodes** (`lua/plugins/luasnip.lua`): the picker
  (`select_choice`) opens **automatically** whenever a choice node becomes the
  active node — a `User LuasnipChoiceNodeEnter` autocmd (scheduled, guarded by
  `choice_active()` so a fast Tab-past doesn't open it stale). `<C-u>`
  (insert/select) reopens it manually; when no choice is active it falls back to
  the built-in `<C-u>` (delete to start of line) via a noremap feedkeys. The
  manual mapping deliberately is **not** an `expr` mapping: the picker is a
  Snacks window, and `nvim_open_win` is forbidden during expr evaluation (E565).
- `spell/` — custom EN+RU dictionaries.
- `blink-cmp-dictionary` source (in `lua/plugins/blink.lua`) suggests
  completions from `dictionaries/american-english.txt` (EN, 50k words) and
  `dictionaries/russian-utf8.txt` (RU, 100k words), filtered via `fzf --filter`
  for speed. `min_keyword_length = 2` and `max_items = 8` so short RU words
  surface sooner and aren't crowded out by 3-item cap. Both wordlists are
  **frequency-ordered** (most common word first: EN from
  david47k/top-english-wordlists, RU from hingston/russian's Leeds Corpus list)
  so common words rank first, not just alphabetically-first matches.
  `get_command_args` overrides fzf's args to add `--tiebreak=index`, since fzf's
  default tiebreak is match length — without this override, ties between
  equal-quality matches would ignore frequency order and fall back to
  shortest-string-wins.
