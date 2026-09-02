---
title: nvim-ui
type: component
updated: 2026-08-14
covers:
  - nvim/lua/plugins/
  - nvim/lua/utils/winbar.lua
  - nvim/lua/utils/fullscreen.lua
  - nvim/lua/utils/kitty.lua
---

# nvim — base config, window UI, kitty integration

Parent: [nvim](nvim.md).

## Why it's built this way

- **LazyVim as the base** (`lazyvim.json`, `lazy-lock.json`): instead of
  assembling a config from scratch, we take the ready-made distro and override
  it selectively in `lua/plugins/*.lua`. Enabled extras: `luasnip`, `dap.core`,
  `mini-files`, `lang.python`.
- Custom stuff in `lua/plugins/` (auto-save, hardtime, render-markdown, bullets,
  vimtex, img-clip, blink, snacks, etc.) — overrides/adds plugins on top of
  LazyVim.
- The Obsidian notes picker normalizes both its query and filename/alias search
  text with Neovim's Unicode-aware lowercase conversion. Snacks' built-in
  matcher lowercases with Lua's ASCII-only `string.lower()`, which otherwise
  makes apparently case-insensitive Russian searches case-sensitive.
- **`gruvbox-material`** as the colorscheme — one gruvbox across all tools, see
  [theming](theming.md). In `colorscheme.lua`, markdown highlights are
  additionally recolored (bold=orange, italic=green).
- Key logic is factored out into `lua/utils/` (folding, kitty, tasks, obsidian,
  gcal) so `keymaps.lua` doesn't bloat.
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
  parsing the _link text_ with the same format, and a format containing `/` no
  longer matches a plain filename — such notes would land in
  `new_file_folder_path` instead of the journal.

- **Buffer count/filename/path indicator lives in `winbar`**, not lualine's
  tabline (`lua/utils/winbar.lua`, mirrors linkarzu's approach).
  `bufferline.nvim` is disabled since winbar covers its role. Reason: winbar is
  per-window and isn't tied to `showtabline`, so it doesn't depend on
  bufferline's logic that used to hide the line after `<leader>bo` — the old
  approach needed autocmd hacks (`OptionSet`/`BufEnter`/etc.) to force
  `showtabline=2` back open; winbar needs none of that. Commit `8bb690a`. The
  update autocmd skips floating windows
  (`nvim_win_get_config(0).relative ~= ""`) — mini.files' explorer panes are
  floats with their own border title, and setting winbar on them stacked a
  garbled extra line (raw buffer name like `minifiles://2//home/shafed`) above
  the content. The winbar logic was pulled out of `config/options.lua` into
  `utils/winbar.lua` (exposing `set_zen(active)`) so the zen toggle in
  `plugins/snacks.lua` can blank the winbar on every normal window while zen
  mode is active and restore it on close. `winbar.zen_active` is the single
  source of truth for zen state — the toggle derives `active` from it rather
  than keeping its own flag, because a local in the plugin spec would reset on
  `:Lazy reload snacks.nvim` and strand the toggle in zen while the modules stay
  active.
- **`snacks.lazygit` opens full-window, not the default float** (2026-08-03):
  Snacks' default lazygit float is ~90% of the nvim window, so lazygit's fixed-
  column layout cut itself off there. `win = { height = 0, width = 0 }` in
  `plugins/snacks.lua` makes it fill the whole nvim window, so it lays out like
  a standalone lazygit. ⚠️ Gotcha: the value is `0`, not `1.0` — in `snacks.win`
  `0` means "full size" while `1.0` means one _absolute cell_ (a 1×1 window).
  Reason it matters: the kitty font switched to the wider Mono Nerd Font
  variant, which squeezes fewer columns into the same width — the float got too
  narrow, standalone terminal still had enough.
- **Zen = Hyprland fullscreen, no nvim float** (2026-08-01): `<leader>uz` no
  longer runs LazyVim's `Snacks.toggle.zen()` (which opens a floating window).
  Instead a custom keymap in `plugins/snacks.lua` toggles a plain `zen_active`
  flag that calls `utils/fullscreen.lua` + `utils/winbar.lua`: the OS window is
  fullscreened, so there's no centered float and nothing is dimmed or narrowed
  inside nvim. The OS chrome is still matched by **`utils/fullscreen.lua`**: on
  open it fullscreens the Hyprland window
  (`hyprctl dispatch 'hl.dsp.window.fullscreen({ action = "set" })'`, only if
  not already fullscreen, and only restored on close if this module is what
  turned it on) and hides kitty's tab bar via the `toggle_tab_bar.py` kitten
  (see [kitty](kitty.md)); wired into the same `<leader>uz` toggle as
  `utils/winbar.lua`. The toggle also enables/disables **Snacks.dim** to dim
  inactive windows in the fullscreen view — the same dimming LazyVim's stock
  `Snacks.zen()` turns on via its default `toggles.dim = true`, so the custom
  Hyprland-fullscreen zen gets the built-in dim behavior without a separate
  twilight.nvim dependency.

## Companion kitty terminal (`<M-t>`, `utils/kitty.lua`)

`<M-t>` (`keymaps.lua`) calls `require("utils.kitty").open()`, which toggles a
companion kitty terminal window (split right/bottom per
`vim.g.tmux_pane_direction`) via `kitten @` remote control, `cd`-ing it into the
current file's directory. This is unrelated to the kitty.conf-level split toggle
mentioned as removed in [sessions](sessions.md) — that one is `C-S--`/`C-S-\`;
this is nvim-driven and zoom/unzoom like the old tmux `resize-pane -Z`.

⚠️ Gotcha (fixed 2026-07-05, two rounds): when unzooming to cd the companion
window into a new directory, the `cd` was sent with
`kitten @ send-text --match='not state:focused'`, which has no tab scoping and
broadcast the `cd` into the non-focused window of **every** tab/session, not
just the current tab's companion. First fix attempt added
`--match-tab=state:focused` alongside `--match` — but in a `stack` layout
(zoomed), `not state:focused` is unreliable and can still resolve to the
_active_ (nvim) window instead of the hidden companion, sending the `cd "..."`
text as literal keypresses into the nvim buffer instead of the terminal. Final
fix: resolve the companion's window `id` directly from `kitten @ ls` (the window
in the tab where `is_active == false` — nvim's own window is always the active
one when `<M-t>` fires from nvim) and match `send-text --match=id:<id>`
explicitly, removing the state-negation guesswork entirely. See
`companion_window_id()` in `utils/kitty.lua`.

⚠️ Gotcha (fixed 2026-08-01): the companion was launched with
`kitten @ launch --location=vsplit --cwd <dir> …` — an explicit `--cwd <path>`
sets `kw.cwd` but **not** `cwd_from`, so the new window was **session-less**
(`created_in_session_name = ""`). Two consequences: (1) pressing `kitty_mod+t`
while the companion was focused inherited the empty session, so the new tab
appeared in _every_ session's tab bar (`tab_bar_filter session:^$` matches empty
session); (2) `goto_session` couldn't find that window by session name and
re-created the session, opening a fresh tab that re-ran the session file (e.g.
`obsidian-sync.sh pull …` — which is why it looked like the sync script caused
the new tab). Fixed by adding `--add-to-session .` to the `launch`, which tags
the window with the source window's session. Same class of fix as `kitty_mod+t`
in [sessions](sessions.md).
