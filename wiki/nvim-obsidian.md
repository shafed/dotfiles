---
title: nvim-obsidian
type: component
updated: 2026-09-10
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

nvim is the editing side of the training logbook.

- `<leader>lr` regenerates `training/logbook.html` through
  `obsidian.regenerate_logbook()`.
- `<leader>lp` saves the buffer as
  `~/github/obsidian/training/Full Body <current year>/YYYY-MM-DD-Training.md`,
  rewrites the first H1 to the same slug when an H1 exists, and regenerates the
  logbook. The session date is prompted with `vim.ui.input`, defaults to today,
  and must be `YYYY-MM-DD`.
- `<leader>lv` opens `~/github/obsidian/training/logbook.html`.
- `<leader>lc` copies the last workout table to the system clipboard in the
  tab-separated shape expected by the external workout workflow.
- `<leader>go` is an explicit manual Git escape hatch implemented in
  `lua/utils/obsidian.lua`. It saves buffers, takes the same lock as
  `obsidian-git-view-sync`, fetches `origin/main`, refuses to commit if local
  Git metadata is behind or diverged, then stages the vault, creates a
  timestamped `Vault backup` commit when needed, and pushes. Routine file
  synchronization remains Syncthing/NAS; the PC does not auto-commit or
  auto-push.
- `nvim-edit-handler.sh` handles `nvim-edit://` links from the generated logbook
  and opens the source training note in the kitty Obsidian session.

## Periodic review of daily notes

`lua/utils/review.lua` turns daily notes into temporary read-only markdown
buffers without creating review artifacts inside the vault:

- `<leader>lw` reviews the previous 7 days.
- `<leader>lm` reviews the previous 30 days.
- `:Review [days]` provides an arbitrary window.
- `<leader>ld` collects the same calendar day from earlier years.
- Untouched template notes are omitted and YAML/meta-bind boilerplate is
  stripped.
- Month-sized reviews include the most-edited markdown files from Git history as
  an attention signal.

Daily notes live under `journal/` with filenames shaped
`YYYY-MM-DD-Weekday.md`.

## Snippets and spell

- `snippets/` contains LuaSnip snippets. Markdown vault templates live in
  `markdown.lua`; LaTeX snippets live in `tex/*.lua` and `bib.lua`.
- Vault note triggers are `;source`, `;project`, `;category`, `;meta`,
  `;creator`, `;quote`, and `;daily`.
- `;date` inserts the current ISO date.
- LuaSnip choice nodes open the choice picker automatically when they become
  active; `<C-u>` reopens it while a choice is active.
- `spell/` contains custom EN+RU dictionaries.
- `blink-cmp-dictionary` uses the tracked English and Russian frequency-ordered
  wordlists and `fzf --filter` for dictionary completions.
