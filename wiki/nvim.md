---
title: nvim
type: component
updated: 2026-07-05
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

## Companion kitty terminal (`<M-t>`, `utils/kitty.lua`)

`<M-t>` (`keymaps.lua`) calls `require("utils.kitty").open()`, which toggles a
companion kitty terminal window (split right/bottom per `vim.g.tmux_pane_direction`)
via `kitten @` remote control, `cd`-ing it into the current file's directory. This
is unrelated to the kitty.conf-level split toggle mentioned as removed in
[sessions](sessions.md) — that one is `C-S--`/`C-S-\`; this is nvim-driven and
zoom/unzoom like the old tmux `resize-pane -Z`.

⚠️ Gotcha (fixed 2026-07-05, two rounds): when unzooming to cd the companion window
into a new directory, the `cd` was sent with
`kitten @ send-text --match='not state:focused'`, which has no tab scoping and
broadcast the `cd` into the non-focused window of **every** tab/session, not just
the current tab's companion. First fix attempt added `--match-tab=state:focused`
alongside `--match` — but in a `stack` layout (zoomed), `not state:focused` is
unreliable and can still resolve to the *active* (nvim) window instead of the
hidden companion, sending the `cd "..."` text as literal keypresses into the nvim
buffer instead of the terminal. Final fix: resolve the companion's window `id`
directly from `kitten @ ls` (the window in the tab where `is_active == false` —
nvim's own window is always the active one when `<M-t>` fires from nvim) and match
`send-text --match=id:<id>` explicitly, removing the state-negation guesswork
entirely. See `companion_window_id()` in `utils/kitty.lua`.

## Clipboard vs. registers (`keymaps.lua`, `utils/tasks.lua`)

`clipboard=""` (`options.lua`) is deliberate: plain `y`/`d`/`ciw`/`x` etc. stay in
Neovim's own unnamed register and never touch the system clipboard, so ordinary
edits don't spam `+` with unrelated text across other apps/sessions. Explicit
`"+`-prefixed mappings are used wherever system-clipboard interop is actually
wanted:

- `<leader>y`/`<leader>Y` — yank (line/to-EOL) to `+`.
- `<leader>p`/`<leader>P` — paste from `+`.
- `<leader>d` — delete to the black hole register (`"_d`), i.e. real "no yank".
- Visual `y` — in markdown, pipes the selection through
  `prettier --prose-wrap never` before landing it in `+`, so hard-wrapped
  paragraph text pastes as unwrapped lines elsewhere; non-markdown just does a
  plain `"+y`.
- Mouse selection (`<LeftRelease>`/`<2-LeftRelease>`) auto-yanks to `+`.

⚠️ Gotcha: an earlier attempt bound a standalone `<leader>x` for "cut" (delete +
copy to `+`), but LazyVim/Trouble already owns `<leader>x` as a which-key group
(`xx`, `xl`, `xq`, `xt`, ...) — a bare `<leader>x` mapping doesn't break those,
but which-key has to wait out `timeoutlen` to disambiguate, so the cut fires
late instead of failing outright. Current approach avoids a dedicated cut
mapping entirely (see below).

⚠️ Gotcha (fixed 2026-07-05): a `FocusLost`/`QuitPre`/`VimSuspend`/`VimLeavePre`
autocmd used to copy `"` into `+` whenever a session lost focus or exited, so
the last yank/delete was available via `<leader>p`/system paste elsewhere
without making every `ciw`/`dd` hit the clipboard live. Removed: `FocusLost` is
a terminal-window focus event, not a "this kitty session became inactive"
event, so switching between kitty sessions (`goto_session`) doesn't reliably
fire it for the session being left — it can fire late, or fire for a
background session instead, so the wrong (stale) session's register would
silently land in `+`. Cross-session clipboard transfer now relies solely on
the explicit mappings above (`<leader>y`, mouse-select) instead of a
focus-event heuristic.

`tasks.yank_text` (bound to `<leader>yc`) copies a task bullet's text without
the `- [ ]`/`- [x]` prefix, straight to `+`. It reuses the same chunk-boundary
walk as `toggle_done` (a task's text can wrap onto following non-bullet,
non-blank lines, e.g. a long todo in `todos.md`), so it selects and yanks the
whole wrapped chunk, not just the cursor's physical line.

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
  completions from `dictionaries/american-english.txt` (EN, 50k words) and
  `dictionaries/russian-utf8.txt` (RU, 100k words), filtered via
  `fzf --filter` for speed. `min_keyword_length = 2` and `max_items = 8` so
  short RU words surface sooner and aren't crowded out by 3-item cap.
  Both wordlists are **frequency-ordered** (most common word first: EN from
  david47k/top-english-wordlists, RU from hingston/russian's Leeds Corpus
  list) so common words rank first, not just alphabetically-first matches.
  `get_command_args` overrides fzf's args to add `--tiebreak=index`, since
  fzf's default tiebreak is match length — without this override, ties
  between equal-quality matches would ignore frequency order and fall back
  to shortest-string-wins.
