---
title: nvim-ui
type: component
updated: 2026-09-10
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
- The vault journal is flat under `journal/`; the date lives in the filename and
  `.moxide.toml` keeps `daily_notes_folder = "journal"`.
- **Buffer count/filename/path indicator lives in `winbar`**, not lualine's
  tabline (`lua/utils/winbar.lua`). `bufferline.nvim` is disabled since winbar
  covers its role. The update autocmd skips floating windows so mini.files
  keeps only its own border title. `utils/winbar.lua` also owns the zen-state
  integration used by `plugins/snacks.lua`.
- **`snacks.lazygit` opens full-window**, using `win = { height = 0, width = 0 }`
  in `plugins/snacks.lua` so lazygit gets the full Neovim window.
- **Zen = Hyprland fullscreen, no nvim float**: `<leader>uz` uses
  `utils/fullscreen.lua` + `utils/winbar.lua`, fullscreens the Hyprland window,
  hides kitty's tab bar, and toggles Snacks.dim for inactive windows.

## Companion kitty terminal (`<M-t>`, `utils/kitty.lua`)

`<M-t>` (`keymaps.lua`) calls `require("utils.kitty").open()`, which toggles a
companion kitty terminal window, split to the right via kitty remote control and
`cd`-ing it into the current file's directory.

The non-zoomed layout is `splits`, so additional requested vertical splits stay
as columns. The companion window is addressed by its resolved kitty window ID,
not by a broad `state:focused`/`not state:focused` selector, so commands stay in
the current tab and cannot be sent into the Neovim window accidentally.

New companion windows are launched with `--add-to-session .`, inheriting the
source kitty session. This keeps session filtering and `goto_session` behavior
stable when the companion is focused or when new tabs are created from it.
