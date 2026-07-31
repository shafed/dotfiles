---
title: nvim
type: component
updated: 2026-07-31
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
- The Obsidian notes picker normalizes both its query and filename/alias search
  text with Neovim's Unicode-aware lowercase conversion. Snacks' built-in
  matcher lowercases with Lua's ASCII-only `string.lower()`, which otherwise
  makes apparently case-insensitive Russian searches case-sensitive.
- **`gruvbox-material`** as the colorscheme — one gruvbox across all tools,
  see [theming](theming.md). In `colorscheme.lua`, markdown highlights are additionally
  recolored (bold=orange, italic=green).
- Key logic is factored out into `lua/utils/` (folding, kitty, tasks, obsidian, gcal)
  so `keymaps.lua` doesn't bloat.
- Nothing in the config rewrites `.moxide.toml` any more. The vault's journal is
  a flat `journal/` — the date lives only in the filename — so
  `daily_notes_folder = "journal"` never goes stale. An earlier `VimEnter`
  autocmd advanced that setting (first to the current month, later the current
  year) and committed the file on every rollover; flattening the folder removed
  the reason for it.

  markdown-oxide also accepts a date in `dailynote` itself (a `/` in the format
  nests, since it builds the path with `Path::join`), which would have kept the
  year directories without the autocmd. That option was rejected: `daily.rs`
  decides where an unresolved `[[2026-07-28-Tuesday]]` link should be created by
  parsing the *link text* with the same format, and a format containing `/` no
  longer matches a plain filename — such notes would land in
  `new_file_folder_path` instead of the journal.
- **Buffer count/filename/path indicator lives in `winbar`**, not lualine's tabline
  (`lua/utils/winbar.lua`, mirrors linkarzu's approach). `bufferline.nvim` is disabled
  since winbar covers its role. Reason: winbar is per-window and isn't tied to
  `showtabline`, so it doesn't depend on bufferline's logic that used to hide the
  line after `<leader>bo` — the old approach needed autocmd hacks
  (`OptionSet`/`BufEnter`/etc.) to force `showtabline=2` back open; winbar needs none
  of that. Commit `8bb690a`. The update autocmd skips floating windows
  (`nvim_win_get_config(0).relative ~= ""`) — mini.files' explorer panes are
  floats with their own border title, and setting winbar on them stacked a
  garbled extra line (raw buffer name like `minifiles://2//home/shafed`) above
  the content. The winbar logic was pulled out of `config/options.lua` into
  `utils/winbar.lua` (exposing `set_zen(active)`) because `Snacks.zen`'s
  floating window still needs the winbar hidden — it inherits winbar from the
  window it was opened from (Neovim copies local-window options on window
  creation) and `utils/winbar`'s update() skips floats, so without an explicit
  hide a stale winbar would linger. `plugins/snacks.lua`'s `zen.on_open`/
  `on_close` call `set_zen(true/false)` to hide/restore it across all windows.
- **Zen = "twilight without zoom"** (2026-07-31): `<leader>uz` (LazyVim's
  `Snacks.toggle.zen()`) dims everything outside the current scope — the
  "twilight" effect — but no longer opens a centered 120-col float. The zen
  window fills the whole editor (`center = false`, `win.width = vim.o.columns`)
  so the buffer is only dimmed, never narrowed or recentered. The OS chrome is
  still matched by **`utils/fullscreen.lua`**: on open it fullscreens the
  Hyprland window (`hyprctl dispatch 'hl.dsp.window.fullscreen({ action = "unset" })'`, only if not already
  fullscreen, and only restored on close if this module is what turned it on)
  and hides kitty's tab bar via the `toggle_tab_bar.py` kitten
  (see [kitty](kitty.md)); wired into `zen.on_open`/`on_close` alongside
  `utils/winbar.lua`.

## Integration with the training logbook

nvim is the editing side of the training logbook; generation and viewing are in
[scripts](scripts.md), invocation from the editor is in [sessions](sessions.md).

- `<leader>lp` (`obsidian.save_training_note`) — saves the buffer as
  `~/obsidian/training/Full Body 2026/YYYY-MM-DD-<h1>.md` (the H1 is
  rewritten into a slug so the filename matches the heading) and **immediately
  triggers** `~/dotfiles/scripts/generate_logbook.py` to regenerate `logbook.html`.
  Prompts for the session date (`vim.ui.input`, defaults to today, validated
  as `YYYY-MM-DD`) so a session logged late can be dated to when it actually
  happened instead of the save date — the date drives both the filename and
  the strict `^\d{4}-\d{2}-\d{2}-Day-\d+$` regex `generate_logbook.py` uses to
  sort/parse sessions.
- A separate keymap opens `logbook.html` via `xdg-open`.
- `obsidian.push_with_cooldown()` — auto commit+push of the `~/obsidian` vault (an hour
  cooldown) so note edits get backed up without manual commits.
- `nvim-edit-handler.sh` in [scripts](scripts.md) — the reverse link: the logbook
  opens a note for editing in nvim.

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
a which-key group), which silently swallowed the `[P]Log` keys (`lc`/`lp`/`lv`/`lr`)
above — the which-key `group` registration alone doesn't override it. Fixed in
`keymaps.lua` by `vim.keymap.del("n", "<leader>l")` and remapping `:Lazy` to
`<leader>L`.

⚠️ Gotcha: `harper_ls` (grammar checking) is **disabled on training notes** —
`excludePatterns` contains `~/obsidian/training/**/*.md` and `Day [123].md`.
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

`mini.files` has its own file-clipboard interop. `<leader>y` copies selected
paths as `text/plain` + `text/uri-list`; for a single image it additionally puts
the actual `image/*` bytes on the clipboard so Claude/browser paste treats it as
an image. `<leader>p` reads `text/uri-list` and copies those files into the
current mini.files directory. This pairs with the Downloads watcher described in
[scripts](scripts.md).

## Russian layout in normal mode (`options.lua` + `autocmds.lua`)

Two complementary mechanisms (added 2026-07-08) so the RU layout doesn't break
normal mode:

- **Layout auto-switch (primary)**: autocmds in `autocmds.lua` force the
  `kanata` xkb device to US on `VimEnter`/`InsertLeave`, remembering the
  previous layout index, and restore it on `InsertEnter` — insert stays RU,
  normal mode is always US, so *every* command/plugin works. Same per-device
  `hyprctl switchxkblayout kanata N` mechanism as `symlayout-watch.sh`
  (see [keymap](keymap.md)); guarded by `executable("hyprctl")` so the config
  still loads outside Hyprland. Command lines deliberately split by purpose:
  `:` forces US because Ex commands are English, while `/` and `?` restore the
  layout remembered from insert mode because search text is usually in the
  document's language. `CmdlineLeave` forces US again for normal mode, but
  unlike `InsertLeave` it doesn't overwrite a remembered RU with US — otherwise
  a `:w` right after typing Russian would make the next insert start in US.
- **langmap (safety net)**: the `hyprctl` calls are async (~10–20 ms), so a
  key hit immediately after `Esc` can still arrive as Cyrillic; the
  ЙЦУКЕН→QWERTY `langmap` in `options.lua` translates it. Covers all letters
  plus punctuation on the same physical keys (`ж→;`, `б→,`, `ю→.`, `х→[`,
  `ъ→]`, `э→'`, `ё→\``). The ambiguous `.→/` and `,→?` pairs are deliberately
  omitted: once normal mode has switched to US, `langmap` cannot distinguish a
  literal US `.` from the same character produced by the RU slash key, so that
  mapping turns repeat (`.`) into search (`/`). `;` and `,` are langmap
  metachars and need `\`-escaping. ⚠️ The pre-2026-07-08 langmap silently
  lacked the `ы→s` pair and punctuation.
- Why langmap alone wasn't enough: it doesn't apply in cmdline (`:ц` is not
  `:w`) and plugins that read input via `getchar()` (flash, which-key,
  mini.surround) bypass it — hence the auto-switch as the primary mechanism.
- ⚠️ Gotcha (fixed same day): pressing `<CR>` in insert mode in a bullet
  list flipped RU→US mid-typing. bullets.vim handles `<CR>` via an
  expression register, which is a transient `i:c:i` mode blip that fires
  `CmdlineLeave` — the async "force US" landed after nvim was already back
  in insert. Fix: the hyprctl callback re-checks `mode()` (scheduled on the
  main loop) and, if a typing mode (`i/R/t/s`, or a `/`/`?` command line) is
  active again, keeps the layout and only refreshes the remembered index. Same
  guard covers a fast `Esc`+`i` or `Esc`+`/` racing the InsertLeave query.
- **flash.nvim is bilingual** (`plugins/flash.lua`): `search.mode` is a
  function turning each typed char into a vim-regex collection of itself +
  its ЙЦУКЕН counterpart on the same physical key (`ghb` →
  `\V\c[gп][hр][bи]`, smartcase), so one `s` search matches both English and
  Russian text — normal mode stays US and you just type the physical keys of
  the Russian word. Works in both directions (Cyrillic input finds Latin
  text). The old separate `ы`/`Ы` flash mappings with RU labels were removed:
  langmap now translates `ы→s`/`Ы→S` before mapping lookup, so they could
  never fire.
  - ⚠️ Gotcha (fixed same day): flash's built-in label-skip logic
    (`Labeler:skip`) only drops a label if the **literal next buffer char**
    continues the match — for Russian text that char is Cyrillic and never
    equals a Latin label, so e.g. typing `н` (key `y`) then `е` (key `t`) to
    narrow "не" instead jumped immediately, because label `t` never got
    skipped. `patch_labeler()` monkey-patches `Labeler.skip` to run a second
    pass with the same skip-pattern, checking each remaining label's
    same-key Cyrillic partner too, so continuable searches keep narrowing
    instead of mis-firing a jump.
  - **f/t/F/T char motions are bilingual too** (`patch_char_mode()`):
    monkey-patches `flash.plugins.char`'s `Char.mode` (the same
    self-key-collection atom as `search.mode`, upstream pattern shape
    otherwise untouched) so `fy` lands on either `y` or `н`, `dtt` deletes up
    to either `t` or `е`, and `;`/`,` repeats inherit it since they reuse the
    same builder.

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

- `snippets/` — LuaSnip snippets. Markdown vault templates live in
  `markdown.lua`; LaTeX snippets live in `tex/*.lua` and `bib.lua`.
- Vault note triggers are `;source`, `;project`, `;category`, `;meta`,
  `;creator`, `;quote`, and `;daily`. The daily snippet derives its heading
  from the filename and adds no metadata.
- There's a `;date` snippet — inserts the current date in ISO format (commit `2e4f335`).
- LuaSnip **choice nodes** (`lua/plugins/luasnip.lua`): the picker
  (`select_choice`) opens **automatically** whenever a choice node becomes the
  active node — a `User LuasnipChoiceNodeEnter` autocmd (scheduled, guarded by
  `choice_active()` so a fast Tab-past doesn't open it stale). `<C-u>`
  (insert/select) reopens it manually; when no choice is active it falls back
  to the built-in `<C-u>` (delete to start of line) via a noremap feedkeys.
  The manual mapping deliberately is **not** an `expr` mapping: the picker is a
  Snacks window, and `nvim_open_win` is forbidden during expr evaluation
  (E565).
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
