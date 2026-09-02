---
title: nvim
type: moc
updated: 2026-08-31
covers:
  - nvim/
---

# nvim

Map of content. Config is **LazyVim** plus selective overrides in
`../nvim/lua/`; nothing here is built from scratch, so the useful knowledge is
which LazyVim behavior was overridden and why.

- **[nvim-ui](nvim-ui.md)** — the base setup and everything about windows: the
  winbar buffer indicator (replacing bufferline), zen mode as a Hyprland
  fullscreen rather than a float, lazygit sizing, the companion kitty terminal
  on `<M-t>`.
- **[nvim-obsidian](nvim-obsidian.md)** — the vault side: training-logbook
  keymaps, periodic review of daily notes, vault snippets and dictionaries.
- **[nvim-clipboard](nvim-clipboard.md)** — why `clipboard=""` is deliberate and
  which explicit mappings do system-clipboard interop, plus mini.files file and
  image handling.
- **[nvim-layout](nvim-layout.md)** — how the Russian layout is kept from
  breaking normal mode: the autocmd layout switch, the langmap safety net, and
  bilingual flash.

## Lua validation

`dots check` parses tracked Lua with the system `luac` (currently Lua 5.4 on
Arch and in CI), even though Neovim itself runs LuaJIT. Keep config syntax valid
under both: in particular, do not reassign numeric/generic `for` control
variables, which Lua 5.4 treats as constant.

## LSP / other exclusions

- `marksman` is disabled in favor of **`markdown_oxide`** (daily-notes, code
  lens, `:Daily` for opening notes via natural language).
- `harper_ls` is enabled only for `markdown`/`typst`, `isolateEnglish=true`,
  ignoring links and `[[wikilinks]]`.

## code-runner

`CRAG666/code_runner.nvim` (`nvim/lua/plugins/code_runner.lua`) is lazy-loaded
on its commands/keys, with the README's recommended mappings: `<leader>rr`
(`RunCode`), `<leader>rf`/`<leader>rft` (`RunFile`, always by filetype, no
project lookup), `<leader>rp` (`RunProject`), `<leader>rc` (`RunClose`).

`RunCode`/`RunProject` auto-detect a project by walking **up from the current
file to filesystem root** looking for `root_markers` (`pom.xml`,
`Cargo.toml`, `go.mod`, `package.json` → `npm start`, `Makefile`,
`CMakeLists.txt`). `~/package.json` exists on this machine (Deepseek/dsh
deps, no `start` script), so `<leader>rr` on _any_ file under the home
directory that has no closer marker bubbles all the way up to it and fails
with `Missing script: "start"`. Use `<leader>rf` for one-off files outside a
real project to skip this lookup entirely.

## neobean

The `neobean`/`nb` aliases were removed from [zsh](zsh.md) in 2026-08-03: they
set `NVIM_APPNAME=linkarzu/dotfiles-latest/neovim/neobean` — a separate
third-party (linkarzu) nvim config — but that directory was never installed on
this machine, so the aliases silently fell back to the default nvim. Don't
resurrect them unless that config is actually set up.
