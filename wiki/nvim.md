---
title: nvim
type: component
updated: 2026-07-04
covers:
  - nvim/
---

# nvim

🚧 Config built on **LazyVim**; customization on top lives in `../nvim/lua/`. Symlink
`~/.config/nvim → ~/dotfiles/nvim` ([bootstrap](bootstrap.md)).

## Why it's built this way

- **LazyVim as the base** (`lazyvim.json`, `lazy-lock.json`): instead of assembling a config
  from scratch, we take the ready-made distro and override it selectively in
  `lua/plugins/*.lua`. Enabled extras: `luasnip`, `dap.core`, `mini-files`,
  `lang.python`.
- Custom stuff in `lua/plugins/` (auto-save, hardtime, render-markdown, bullets, vimtex,
  img-clip, blink, snacks, etc.) — overrides/adds plugins on top of LazyVim.
- **`gruvbox-material`** as the colorscheme — one gruvbox across all tools,
  see [theming](theming.md). In `colorscheme.lua`, markdown highlights are additionally
  recolored (bold=orange, italic=green).
- Key logic is factored out into `lua/utils/` (folding, kitty, tasks, obsidian, gcal)
  so `keymaps.lua` doesn't bloat.
- **Buffer count/filename/path indicator lives in `winbar`**, not lualine's tabline
  (`config/options.lua`, mirrors linkarzu's approach). `bufferline.nvim` is disabled
  since winbar covers its role. Reason: winbar is per-window and isn't tied to
  `showtabline`, so it doesn't depend on bufferline's logic that used to hide the
  line after `<leader>bo` — the old approach needed autocmd hacks
  (`OptionSet`/`BufEnter`/etc.) to force `showtabline=2` back open; winbar needs none
  of that. Commit `8bb690a`. The update autocmd skips floating windows
  (`nvim_win_get_config(0).relative ~= ""`) — mini.files' explorer panes are
  floats with their own border title, and setting winbar on them stacked a
  garbled extra line (raw buffer name like `minifiles://2//home/shafed`) above
  the content.

## Integration with the training logbook

nvim is the editing side of the training logbook; generation and viewing are in
[scripts](scripts.md), invocation from the editor is in [sessions](sessions.md).

- `<leader>lp` (`obsidian.save_training_note`) — saves the buffer as
  `~/obsidian/periodic/training/Full Body 2026/YYYY-MM-DD-<h1>.md` (the H1 is
  rewritten into a slug so the filename matches the heading) and **immediately
  triggers** `~/dotfiles/scripts/generate_logbook.py` to regenerate `logbook.html`.
- A separate keymap opens `logbook.html` via `xdg-open`.
- `obsidian.push_with_cooldown()` — auto commit+push of the `~/obsidian` vault (an hour
  cooldown) so note edits get backed up without manual commits.
- `nvim-edit-handler.sh` in [scripts](scripts.md) — the reverse link: the logbook
  opens a note for editing in nvim.

⚠️ Gotcha: LazyVim core binds `<leader>l` directly to `:Lazy` (exact match, not
a which-key group), which silently swallowed the `[P]Log` keys (`lc`/`lp`/`lv`/`lr`)
above — the which-key `group` registration alone doesn't override it. Fixed in
`keymaps.lua` by `vim.keymap.del("n", "<leader>l")` and remapping `:Lazy` to
`<leader>L`.

⚠️ Gotcha: `harper_ls` (grammar checking) is **disabled on training notes** —
`excludePatterns` contains `~/obsidian/periodic/training/**/*.md` and `Day [123].md`.
Reason: training notes are tables/abbreviations, and harper chokes on false
positives. Commit `ef70575` ("recursive disable harper in training").

## LSP / other exclusions

- `marksman` is disabled in favor of **`markdown_oxide`** (daily-notes, code lens,
  `:Daily` for opening notes via natural language).
- `harper_ls` is enabled only for `markdown`/`typst`, `isolateEnglish=true`,
  ignoring links and `[[wikilinks]]`.

## neobean

The `neobean`/`nb` aliases in [zsh](zsh.md) launch nvim with
`NVIM_APPNAME=linkarzu/dotfiles-latest/neovim/neobean` — a separate third-party
config (linkarzu) running alongside the main one, without interfering with it. TODO: confirm
that this `NVIM_APPNAME` directory is actually installed on the machine (it's not in the repo).

## Snippets and spell

- `snippets/` — luasnip snippets, a lot of them for LaTeX (`tex/*.lua`, `bib.lua`).
- There's a `;date` snippet — inserts the current date in ISO format (commit `2e4f335`).
- `spell/` — custom EN+RU dictionaries.
- `blink-cmp-dictionary` source (in `lua/plugins/blink.lua`) suggests
  completions from `dictionaries/american-english.txt` (EN) and
  `dictionaries/russian-utf8.txt` (RU, ~1.5M inflected forms), filtered via
  `fzf --filter` for speed. `min_keyword_length = 2` and `max_items = 8` so
  short RU words surface sooner and aren't crowded out by 3-item cap.
