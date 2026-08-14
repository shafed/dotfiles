---
title: nvim-layout
type: component
updated: 2026-08-14
covers:
  - nvim/lua/config/options.lua
  - nvim/lua/config/autocmds.lua
  - nvim/lua/plugins/flash.lua
---

# nvim — Russian layout in normal mode

Parent: [nvim](nvim.md). The same `kanata` xkb device is driven by
[keymap](keymap.md) and `../scripts/symlayout-watch.sh`.

## Russian layout in normal mode (`options.lua` + `autocmds.lua`)

Two complementary mechanisms (added 2026-07-08) so the RU layout doesn't break
normal mode:

- **Layout auto-switch (primary)**: autocmds in `autocmds.lua` force the
  `kanata` xkb device to US on `VimEnter`/`InsertLeave`, remembering the
  previous layout index, and restore it on `InsertEnter` — insert stays RU,
  normal mode is always US, so _every_ command/plugin works. Same per-device
  `hyprctl switchxkblayout kanata N` mechanism as `symlayout-watch.sh` (see
  [keymap](keymap.md)); guarded by `executable("hyprctl")` so the config still
  loads outside Hyprland. Command lines deliberately split by purpose: `:`
  forces US because Ex commands are English, while `/` and `?` restore the
  layout remembered from insert mode because search text is usually in the
  document's language. `CmdlineLeave` forces US again for normal mode, but
  unlike `InsertLeave` it doesn't overwrite a remembered RU with US — otherwise
  a `:w` right after typing Russian would make the next insert start in US.
  - Snacks pickers are treated like the `:` cmdline: the picker input is a
    prompt buffer (`snacks_picker_input`) that starts insert mode, so while a
    picker is open the layout is forced to US (otherwise `InsertEnter` would
    restore RU mid-search). While a picker is open, `InsertEnter`/`InsertLeave`
    skip the restore/remember entirely, so a picker session never clobbers
    `insert_layout`. On close no layout is restored — normal mode is US anyway,
    and re-entering insert picks up RU from `insert_layout`.
- **langmap (safety net)**: the `hyprctl` calls are async (~10–20 ms), so a key
  hit immediately after `Esc` can still arrive as Cyrillic; the ЙЦУКЕН→QWERTY
  `langmap` in `options.lua` translates it. Covers all letters plus punctuation
  on the same physical keys (`ж→;`, `б→,`, `ю→.`, `х→[`, `ъ→]`, `э→'`,
  `ё→\``). The ambiguous `.→/`and`,→?`pairs are deliberately omitted: once normal mode has switched to US,`langmap`cannot distinguish a literal US`.` from the same character produced by the RU slash key, so that mapping turns repeat (`.`) into search (`/`). `;`and`,`are langmap metachars and need`\`-escaping.
  ⚠️ The pre-2026-07-08 langmap silently lacked the `ы→s` pair and punctuation.
- Why langmap alone wasn't enough: it doesn't apply in cmdline (`:ц` is not
  `:w`) and plugins that read input via `getchar()` (flash, which-key,
  mini.surround) bypass it — hence the auto-switch as the primary mechanism.
- ⚠️ Gotcha (fixed same day): pressing `<CR>` in insert mode in a bullet list
  flipped RU→US mid-typing. bullets.vim handles `<CR>` via an expression
  register, which is a transient `i:c:i` mode blip that fires `CmdlineLeave` —
  the async "force US" landed after nvim was already back in insert. Fix: the
  hyprctl callback re-checks `mode()` (scheduled on the main loop) and, if a
  typing mode (`i/R/t/s`, or a `/`/`?` command line) is active again, keeps the
  layout and only refreshes the remembered index. Same guard covers a fast
  `Esc`+`i` or `Esc`+`/` racing the InsertLeave query.
- **flash.nvim is bilingual** (`plugins/flash.lua`): `search.mode` is a function
  turning each typed char into a vim-regex collection of itself + its ЙЦУКЕН
  counterpart on the same physical key (`ghb` → `\V\c[gп][hр][bи]`, smartcase),
  so one `s` search matches both English and Russian text — normal mode stays US
  and you just type the physical keys of the Russian word. Works in both
  directions (Cyrillic input finds Latin text). The old separate `ы`/`Ы` flash
  mappings with RU labels were removed: langmap now translates `ы→s`/`Ы→S`
  before mapping lookup, so they could never fire.
  - ⚠️ Gotcha (fixed same day): flash's built-in label-skip logic
    (`Labeler:skip`) only drops a label if the **literal next buffer char**
    continues the match — for Russian text that char is Cyrillic and never
    equals a Latin label, so e.g. typing `н` (key `y`) then `е` (key `t`) to
    narrow "не" instead jumped immediately, because label `t` never got skipped.
    `patch_labeler()` monkey-patches `Labeler.skip` to run a second pass with
    the same skip-pattern, checking each remaining label's same-key Cyrillic
    partner too, so continuable searches keep narrowing instead of mis-firing a
    jump.
  - **f/t/F/T char motions are bilingual too** (`patch_char_mode()`):
    monkey-patches `flash.plugins.char`'s `Char.mode` (the same
    self-key-collection atom as `search.mode`, upstream pattern shape otherwise
    untouched) so `fy` lands on either `y` or `н`, `dtt` deletes up to either
    `t` or `е`, and `;`/`,` repeats inherit it since they reuse the same
    builder.
