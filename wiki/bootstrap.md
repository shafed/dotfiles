---
title: bootstrap
type: topic
updated: 2026-07-04
covers:
  - zsh/zshrc
  - zsh/zprofile
---

# Bootstrap — deploying on a new machine

🚧 Platform: Arch Linux + Hyprland. The Windows/WSL part is removed (see
[decisions](decisions.md)). Session autostart — `../zsh/zprofile`: on tty1 with no
`$DISPLAY`, runs `exec uwsm start hyprland-uwsm.desktop` (not the raw
`start-hyprland` binary) — uwsm wraps Hyprland in a proper systemd user
session so `graphical-session.target` and the session environment are
available to user services; see [hypr](hypr.md) for why this matters.

## Deployment mechanism

There is **no** install script. Configs are wired up via **manual symlinks**
`~/.config/<tool> → ~/dotfiles/<tool>` (plus `~/.zshrc`). Reason for the choice and
the rejected `stow` — see [decisions](decisions.md).

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
complete (see [decisions](decisions.md)). The `tmux/`/`wezterm/` directories in the repo
were left untouched.

## Packages

Confirmed by the repo's configs (not guessed): `hyprland`, `kanata`,
`kitty`, `waybar`, `yazi`, `neovim`, `zsh` + `oh-my-zsh` (auto-installed from
zshrc), `zoxide`, `fzf`, `darkman`, `lazygit`, `sioyek`, `zathura`, `xray`.
From [scripts](scripts.md)/[zsh](zsh.md) also visible: `yt-dlp`, `brotab`, `aichat`,
`taskwarrior`, `todoist`, `copyq`, `python` (generate_logbook.py).

TODO: exact pacman vs AUR package names and versions — not recorded (check
during deployment).

## Manual setup outside the repo (TODO clarify)

- Firefox extension for `brotab` (bookmarks.sh focuses the tab), see
  [scripts](scripts.md).
- systemd user services from `~/.config/systemd`.
- Layouts: kanata (see [keymap](keymap.md)). The old `im-select` in [zsh](zsh.md)
  (Windows path) removed 2026-07-01.
- oh-my-zsh and custom plugins are pulled in automatically on the first run of
  zshrc (no install script needed).

✅ fixed 2026-07-01: secrets (`OPENROUTER_API_KEY`, `TODOIST_API_TOKEN`)
removed from `../zsh/zshrc`. The keys remain in git history — rotate them
(see [zsh](zsh.md)).
