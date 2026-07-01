---
title: bootstrap
type: topic
updated: 2026-07-01
covers:
  - zsh/zshrc
  - zsh/zprofile
---

# Bootstrap — deploying on a new machine

🚧 Platform: Arch Linux + Hyprland. The Windows/WSL part is removed (see
[[decisions]]). Session autostart — `../zsh/zprofile`: on tty1 with no
`$DISPLAY`, runs `exec start-hyprland`.

## Deployment mechanism

There is **no** install script. Configs are wired up via **manual symlinks**
`~/.config/<tool> → ~/dotfiles/<tool>` (plus `~/.zshrc`). Reason for the choice and
the rejected `stow` — see [[decisions]].

Symlinks confirmed on the current machine (`ls -la ~/.config/`):

| target (~/.config/) | source (~/dotfiles/) |
| --- | --- |
| `hypr` | `hypr` |
| `kitty` | `kitty` |
| `nvim` | `nvim` |
| `kanata` | `kanata` |
| `waybar` | `waybar` |
| `yazi` | `yazi` |
| `darkman` | `darkman` |
| `lazygit` | `lazygit` |
| `sioyek` | `sioyek` |
| `zathura` | `zathura` |
| `systemd` | `systemd` |
| `xray` | `xray` |
| `~/.zshrc` | `zsh/zshrc` |

✅ fixed 2026-07-01: legacy symlinks `~/.config/tmux` and `~/.config/wezterm`
(both pointed into dotfiles) were removed — the switch to kitty native sessions is
complete (see [[decisions]]). The `tmux/`/`wezterm/` directories in the repo
were left untouched.

## Packages

Confirmed by the repo's configs (not guessed): `hyprland`, `kanata`,
`kitty`, `waybar`, `yazi`, `neovim`, `zsh` + `oh-my-zsh` (auto-installed from
zshrc), `zoxide`, `fzf`, `darkman`, `lazygit`, `sioyek`, `zathura`, `xray`.
From [[scripts]]/[[zsh]] also visible: `yt-dlp`, `brotab`, `aichat`,
`taskwarrior`, `todoist`, `copyq`, `python` (generate_logbook.py).

TODO: exact pacman vs AUR package names and versions — not recorded (check
during deployment).

## Manual setup outside the repo (TODO clarify)

- Firefox extension for `brotab` (bookmarks.sh focuses the tab), see
  [[scripts]].
- systemd user services from `~/.config/systemd`.
- Layouts: kanata (see [[keymap]]). The old `im-select` in [[zsh]]
  (Windows path) removed 2026-07-01.
- oh-my-zsh and custom plugins are pulled in automatically on the first run of
  zshrc (no install script needed).

✅ fixed 2026-07-01: secrets (`OPENROUTER_API_KEY`, `TODOIST_API_TOKEN`)
removed from `../zsh/zshrc`. The keys remain in git history — rotate them
(see [[zsh]]).
