---
title: zsh
type: component
updated: 2026-08-03
covers:
  - zsh/zshrc
  - zsh/zprofile
---

# zsh

🚧 Base oh-my-zsh + manual auto-install of plugins. Main file — `../zsh/zshrc`
(symlink `~/.zshrc → ~/dotfiles/zsh/zshrc`, see [bootstrap](bootstrap.md)).

## Why it's built this way

- **oh-my-zsh, `gruvbox-material` theme** — a single gruvbox across all tools
  (kitty/nvim/fzf), see [theming](theming.md). Colors for `zsh-syntax-highlighting`,
  `LS_COLORS`, `FZF_DEFAULT_OPTS`, `BAT_THEME`, `LESS_TERMCAP_*` are hardcoded to
  gruvbox-material dark medium directly in zshrc, to match the kitty theme.
- **Plugins auto-install** (`zsh-autosuggestions`,
  `zsh-syntax-highlighting`, `zsh-vi-mode`): if `$ZSH` or a plugin is missing,
  zshrc clones them itself. Reason — a new machine has no install script
  ([bootstrap](bootstrap.md)), so the bootstrap is baked into the config itself.
- **`bindkey -v` + zsh-vi-mode**: vi mode in the shell; `gh`/`gl` are rebound to
  start/end of line to match nvim muscle memory.
- **Alt-t (`kitty_other_window`)** mirrors nvim's `<M-t>`: jump to the neighboring kitty
  window + `goto_layout stack`. `KITTY_WINDOW_DIRECTION="right"` must match
  `vim.g.tmux_pane_direction` in nvim. Registered with `zvm_bindkey` in both `vicmd`
  and `viins`, from the **`zvm_after_init`** hook (not `zvm_after_lazy_keybindings`,
  see `ZVM_LAZY_KEYBINDINGS=false` below). See [kitty](kitty.md), [sessions](sessions.md),
  [nvim](nvim.md).
- **`ZVM_LAZY_KEYBINDINGS=false`** (plain assignment **before** `plugins=()`/
  `source oh-my-zsh.sh` — must not be set inside `zvm_config()`, see below) — fixes
  "Alt-t doesn't fire after exiting Claude Code in a fresh pane". By default
  zsh-vi-mode defers all `vicmd` keybindings into a lazy list that it only flushes
  the *first time the shell enters normal mode*; open a pane, go straight into
  `claude`, exit, and the `^[t` binding was never installed yet — so the first
  post-`claude` Alt-t just drops a bare Esc into normal mode and the trailing `t`
  gets swallowed as a motion (it only starts "working" once some prior mode-switch,
  e.g. that very failed Alt-t, flushes the list — which is why it looked
  intermittent/order-dependent while debugging). Disabling lazy loading installs
  `vicmd` bindings eagerly at load instead, so the binding exists from the first
  prompt onward — confirmed live by spawning a fresh kitty window and checking
  `bindkey -M vicmd | grep '^[t'`. ⚠️ Must be a pre-source assignment, not set inside
  `zvm_config()`: the plugin reads this var and initializes the lazy list near the
  **top** of its file, long before it calls `zvm_config` at the very end — setting it
  there is silently too late and (worse) disables the lazy-flush path without ever
  installing the binding another way, which is a trap worth avoiding twice. Because
  lazy loading is off, bindings are set from **`zvm_after_init`** (fires once at the
  end of plugin init) rather than `zvm_after_lazy_keybindings` (never called when
  `ZVM_LAZY_KEYBINDINGS=false`). See [keymap](keymap.md).
- **`ZVM_ESCAPE_KEYTIMEOUT=0.2`** (default `0.03`): kanata's `lalt` tap-hold (~160ms,
  `kanata/config.kbd` `th $tot 160`) means Alt-t's trailing `t` can arrive after
  zsh-vi-mode's default 30ms escape window, leaving a bare Esc + literal `t` instead
  of firing the binding. Unrelated to the lazy-keybindings issue above — both were
  needed at different times for what looked like the same symptom.
- **`ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT` in `zvm_config()`** — every new prompt line
  starts in INSERT mode. zsh-vi-mode otherwise restores whatever mode the previous
  program left the shell in; a TUI like Claude Code exits in NORMAL mode, so the next
  `^[t` would be read as bare Esc + vi `t` motion. It lives in `zvm_config()` because
  `$ZVM_MODE_INSERT` is a `ZVM_*` constant that only exists once the plugin is sourced.
- **Cursor styling is the plugin default (enabled)** — `ZVM_CURSOR_STYLE_ENABLED` was
  briefly `false` (`e834340`) to dodge a `zvm_cursor_style` regex error on some
  terminals/apps, then flipped to `true` (`5089924`), where it's the default and thus a
  no-op. The dead line was removed 2026-08-03; if the regex error ever resurfaces, set
  it to `false` to disable zsh-vi-mode's per-mode cursor shapes.
- **Alt-e (`_aichat_zsh`)** — runs the current buffer through `aichat -r %shell%`
  and substitutes in the resulting command.

## Functions

- `y()` — a wrapper over yazi: writes the cwd to a temp file and `cd`s into it on exit
  (file-manager navigation changes the shell's directory).
- `kitty_other_window()` — see above, integration with kitty splits.

## Env and aliases

- `EDITOR`/`VISUAL=nvim`, `BROWSER=helium-browser`, `TERMCMD=kitty` (after dropping
  Windows, see [decisions](decisions.md)).
- nvim: `v`=nvim.
- misc: `y`=yazi, `ta`/`tl`=taskwarrior, `ai`=aichat, `pulldeez`=git pull
  dotfiles + resource, `cdd`=`cd -`.
- `cd` is overridden with **zoxide** (`zoxide init zsh --cmd cd`).

⚠️ Gotcha: `--cmd cd` makes zoxide's query logic live under `cd` only — unlike
the default `zoxide init zsh` (no `--cmd`), it does **not** also define a `z`
command. `cdd` was aliased to `z -` and silently failed (`z: command not
found`); fixed to `cd -`, since that's what zoxide's `cd` override maps `-` to.

⚠️ Gotcha: zoxide-init must come **last** in zshrc. OMZ installs its own
chpwd hooks, which causes `zoxide doctor` to give a false "initialized too early" —
silenced via `_ZO_DOCTOR=0`.

## Gotchas for cleanup

✅ fixed 2026-07-01: **dead `sync-vi`/`sv` aliases** (`cp -r ~/.config/nvim/
~/dotfiles/.config/`) removed. The `~/dotfiles/.config/` directory didn't exist, and nvim
is now its own symlink `~/.config/nvim → ~/dotfiles/nvim` ([bootstrap](bootstrap.md)).

✅ fixed 2026-07-01: **im-select machinery removed** —
`IM_SELECT_CMD="/mnt/c/windows/im-select.exe"` (a WSL leftover) along with `set_im`/
`get_im`/`zle-im-keymap-select` and its registration. Layout switching on this system is
handled by kanata ([keymap](keymap.md)); the zsh mechanism was redundant.

✅ fixed 2026-07-01: **secrets removed** from `../zsh/zshrc` —
`OPENROUTER_API_KEY` and `TODOIST_API_TOKEN` (the export lines were stripped). The keys
remain in git history, so they should still be **rotated**. Note:
`TODOIST_API_TOKEN` is no longer exported, so any todoist integration
relying on it will stop working without an external source for the token.

✅ fixed 2026-07-01: **duplicate `export PATH="$HOME/.local/bin:$PATH"`** removed —
one line remains.

✅ fixed 2026-07-02: **`vif`/`vip` aliases replaced with `v`** — the dedicated
"open config"/"open plugins" shortcuts were dropped in favor of a plain `v="nvim"`
alias alongside the existing `vi`.
