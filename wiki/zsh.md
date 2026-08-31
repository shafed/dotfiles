---
title: zsh
type: component
updated: 2026-08-31
covers:
  - zsh/zshrc
  - zsh/zprofile
  - zsh/completions/_dots
---

# zsh

oh-my-zsh with plugins that install themselves. Main file — `../zsh/zshrc`
(symlink `~/.zshrc`, see [bootstrap](bootstrap.md)).

## Why it's built this way

- **Plugins clone themselves** if `$ZSH` or a plugin is missing, so a fresh
  machine needs no plugin step in `dots apply` — the shell bootstraps itself.
- **Gruvbox is hardcoded**, not inherited: `zsh-syntax-highlighting`,
  `LS_COLORS`, `FZF_DEFAULT_OPTS`, `BAT_THEME` and `LESS_TERMCAP_*` each carry
  their own copy of the palette to match kitty. One of the duplication sites
  [theming](theming.md) warns about.
- **`cd` is zoxide** (`zoxide init zsh --cmd cd`), not plain `cd`.
- **`ds` is the interactive shorthand for `dots`**; the CLI itself owns its
  abbreviated subcommands. `dots aliases`/`ds al` is the authoritative list.
- **`dots` completion is installed as an Oh My Zsh custom completion.** The
  base profile links `zsh/completions/_dots` to
  `~/.oh-my-zsh/custom/completions/_dots`. That loader asks
  `dots completion zsh` for the actual function, so canonical command names and
  abbreviations come from the same `scripts/dots-lib.sh` metadata as dispatch
  and help instead of being copied into zshrc. Completion is also registered for
  the `ds` alias.

## zsh-vi-mode: three settings that all look like the same bug

`<M-t>` (`kitty_other_window`, mirroring nvim's companion-terminal toggle) kept
failing intermittently. Three independent causes, each fixed by a different
knob — knowing they are separate is the point, because any one of them alone
produces the same symptom: a bare Esc lands in normal mode and the trailing `t`
is eaten as a motion.

- ⚠️ **`ZVM_LAZY_KEYBINDINGS=false` must be assigned _before_ sourcing
  oh-my-zsh, never inside `zvm_config()`.** By default the plugin defers all
  `vicmd` bindings and flushes them only when the shell _first enters normal
  mode_ — so opening a pane, running `claude`, and exiting means `^[t` was never
  installed. Setting the var inside `zvm_config()` is silently too late: the
  plugin reads it near the top of its file and calls `zvm_config` at the very
  end, so you get the lazy path disabled _and_ no binding installed — strictly
  worse than leaving it alone.
- ⚠️ **`ZVM_ESCAPE_KEYTIMEOUT=0.2`** (default `0.03`) — kanata's `lalt` tap-hold
  is ~160 ms (`th $tot 160` in `kanata/config.kbd`), so the trailing `t` arrives
  after the default 30 ms escape window. A kanata timing change breaks this.
- ⚠️ **`ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT`** — otherwise each prompt inherits
  the mode the last program left behind, and a TUI like Claude Code exits in
  NORMAL. This one _does_ belong in `zvm_config()`, because `$ZVM_MODE_INSERT`
  only exists after the plugin is sourced.

Because lazy loading is off, bindings are registered from **`zvm_after_init`**;
`zvm_after_lazy_keybindings` never fires. `KITTY_WINDOW_DIRECTION` must stay in
sync with `vim.g.tmux_pane_direction` in [nvim-ui](nvim-ui.md). See also
[keymap](keymap.md), [sessions](sessions.md).

If a `zvm_cursor_style` regex error ever appears on some terminal, set
`ZVM_CURSOR_STYLE_ENABLED=false` — it is at its default (`true`) now.

## Gotchas

⚠️ `zoxide init zsh --cmd cd` defines **only** `cd`, not `z`. An alias using
`z -` fails with `z: command not found`; use `cd -`.

⚠️ zoxide init must come **last** in zshrc. OMZ installs its own chpwd hooks,
which makes `zoxide doctor` report a false "initialized too early" — silenced
with `_ZO_DOCTOR=0`.

⚠️ `OPENROUTER_API_KEY` and `TODOIST_API_TOKEN` were stripped from zshrc on
2026-07-01, but **remain in git history and should still be rotated**. Anything
that depended on `TODOIST_API_TOKEN` needs another source for it.
