---
title: zsh
type: component
updated: 2026-07-05
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
  `vim.g.tmux_pane_direction` in nvim. See [kitty](kitty.md), [sessions](sessions.md),
  [nvim](nvim.md).
- **`ZVM_ESCAPE_KEYTIMEOUT=0.2`** (default is `0.03`): needed because kanata's `lalt` is a
  tap-hold key with a ~160ms hold-resolution delay (`kanata/config.kbd`, `th $tot 160`), so
  the trailing `t` of Alt-t often arrived after zsh-vi-mode's default 30ms escape-sequence
  window closed. This left a bare Esc + a literal `t` (vi's till-char motion) in `vicmd`
  instead of firing `zvm_bindkey vicmd '^[t' kitty_other_window` — the binding only
  misfired in vi **normal** mode, not insert mode, which is what made it look like "`<M-t>`
  doesn't close in normal mode". See [keymap](keymap.md) for the kanata timing.
- **Alt-e (`_aichat_zsh`)** — runs the current buffer through `aichat -r %shell%`
  and substitutes in the resulting command.

## Functions

- `y()` — a wrapper over yazi: writes the cwd to a temp file and `cd`s into it on exit
  (file-manager navigation changes the shell's directory).
- `kitty_other_window()` — see above, integration with kitty splits.

## Env and aliases

- `EDITOR`/`VISUAL=nvim`, `BROWSER=firefox`, `TERMCMD=kitty` (after dropping
  Windows, see [decisions](decisions.md)).
- nvim: `vi`/`v`=nvim; `neobean`/`nb` —
  alternate `NVIM_APPNAME` (see [nvim](nvim.md)).
- misc: `y`=yazi, `ta`/`tl`=taskwarrior, `ai`=aichat, `pulldeez`=git pull
  dotfiles + resource, `cdd`=`z -`.
- `cd` is overridden with **zoxide** (`zoxide init zsh --cmd cd`).

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
