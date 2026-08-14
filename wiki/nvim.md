---
title: nvim
type: moc
updated: 2026-08-14
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
  on `<M-t>`, and `:Restart`.
- **[nvim-obsidian](nvim-obsidian.md)** — the vault side: training-logbook
  keymaps, periodic review of daily notes, vault snippets and dictionaries.
- **[nvim-clipboard](nvim-clipboard.md)** — why `clipboard=""` is deliberate and
  which explicit mappings do system-clipboard interop, plus mini.files file and
  image handling.
- **[nvim-layout](nvim-layout.md)** — how the Russian layout is kept from
  breaking normal mode: the autocmd layout switch, the langmap safety net, and
  bilingual flash.

## LSP / other exclusions

- `marksman` is disabled in favor of **`markdown_oxide`** (daily-notes, code
  lens, `:Daily` for opening notes via natural language).
- `harper_ls` is enabled only for `markdown`/`typst`, `isolateEnglish=true`,
  ignoring links and `[[wikilinks]]`.

## neobean

The `neobean`/`nb` aliases were removed from [zsh](zsh.md) in 2026-08-03: they
set `NVIM_APPNAME=linkarzu/dotfiles-latest/neovim/neobean` — a separate
third-party (linkarzu) nvim config — but that directory was never installed on
this machine, so the aliases silently fell back to the default nvim. Don't
resurrect them unless that config is actually set up.
