---
title: decisions
type: topic
updated: 2026-07-04
---

# decisions — major decisions and rejected alternatives

🚧 Key "why it's done this way" page. Each entry:
**decision → reason → rejected alternative → date**.

## Recorded

### tmux → kitty native sessions (2026-06)
- **Decision**: remove tmux; do multiplexing and splits with native kitty
  (windows/tabs/layouts). Navigation hotkeys are sent by kanata as `C-S-*`.
- **Reason**: tmux duplicated terminal functionality — its own prefix (`C-s`), its
  own rendering, an extra layer over kitty's GPU rendering. Native kitty gives
  splits and scrollback with no intervening layer; `<M-t>` in nvim and Alt-t in
  [zsh](zsh.md) mirror the old tmux zoom via `kitten @`.
- **Rejected**: staying on tmux (extra layer, theme/navigation desync);
  wezterm's multiplexer (wezterm is also out of use).
- Trade-off: sessions are now tied to kitty; the `~/.config/tmux` config remains
  as a legacy symlink ([bootstrap](bootstrap.md)). See [sessions](sessions.md),
  [kitty](kitty.md).

### kanata as the single keymap engine
- **Decision**: home-row mods, chords, layers, and force-layout — all in kanata,
  rather than spread across hypr `bind`, kitty `map`, zsh `bindkey`.
- **Reason**: kanata operates at the input-device level, so one layout works
  identically across all apps (terminal, browser, IDE). Otherwise the same
  chords would have to be duplicated in every config, risking desync.
  Apps receive ready-made `C-S-*`/`Super` events.
- **Rejected**: separate per-app bindings (hypr/kitty/zsh) — duplication and
  behavior divergence between apps.
- See [kanata](kanata.md), [keymap](keymap.md).

### Removal of Windows/WSL legacy (2026-07-01)
- Removed `autohotkey/`, `glazewm/`, `wezterm/`, `start.bat`; cleaned up glazewm/WSL
  aliases and `winuser`/`explorer.exe`/`powershell.exe` from zshrc; `TERMCMD` → kitty.
- Reason: the machine is now Arch/Hyprland only; the Windows part is no longer needed.
- `awesome/` left as legacy but not yet removed (deliberately).

### Manual symlinks instead of stow/an install script (2026-07-01, superseded 2026-07-04)
- **Decision**: wire up configs manually via symlinks `~/.config/<tool> →
  ~/dotfiles/<tool>` (list — [bootstrap](bootstrap.md)).
- **Reason**: one personal machine, few symlinks created only once —
  an install script/`stow` would be extra infrastructure with no payoff. It's
  transparently visible what links where.
- **Rejected**: `stow` (an extra dependency and directory structure for the same
  result); a generative install script (nothing to automate for a one-off setup).
- **Superseded 2026-07-04**: switched to `bootstrap.sh` — see next entry. The
  "revisit when" trigger (second machine / growing symlink count) was hit.

### Bootstrap script with plain symlinks, not GNU Stow (2026-07-04)
- **Decision**: `bootstrap.sh` at repo root checks for required commands/packages
  (report-only, no auto-install), then `ln -sfvn`s each top-level config dir
  into `~/.config/<name>` (whole-directory symlinks: `hypr`, `kitty`, `nvim`,
  `kanata`, `waybar`, `yazi`, `darkman`, `lazygit`, `sioyek`, `zathura`,
  `systemd`), plus `zsh/zshrc` → `~/.zshrc` and `zsh/zprofile` → `~/.zprofile`.
- **Reason**: automates what was manual, is idempotent (`ln -sfn` re-running is
  a safe no-op), and needs no new dependency.
- **Rejected**: **GNU Stow** — tried first, but stow's model is per-file
  fan-out that expects the package's internal path to mirror the target
  (`pkg/.config/pkg/file` → `~/.config/pkg/file`). This repo's layout is flat
  (`dotfiles/hypr/hyprland.conf` directly), which whole-directory symlinks
  handle natively but stow's per-file placement fights: tested against the
  live `~/.config` (already whole-directory symlinks) and stow either
  unpacked them into real directories with per-file links (a structural
  change with no benefit) or hit outright conflicts (e.g. `nvim/init.lua` vs
  `yazi/init.lua`) that aborted the whole operation. Restructuring the repo to
  fit stow's model was rejected as unnecessary extra churn for a one-machine
  (now few-machine) setup.
  Also rejected: auto-installing missing packages via pacman/yay — more
  invasive and requires sudo; left as a manual step so the user reviews
  what's installed.
- See [bootstrap](bootstrap.md).
