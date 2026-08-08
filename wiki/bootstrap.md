---
title: bootstrap
type: topic
updated: 2026-08-08
covers:
  - bootstrap.sh
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

Run `./bootstrap.sh` from the repo root. It checks for required commands
(report-only — see [decisions](decisions.md) for why not auto-install), then
`ln -sfvn`s each top-level config dir as a whole into `~/.config/<name>`, plus
`zsh/zshrc` → `~/.zshrc` and `zsh/zprofile` → `~/.zprofile`. Idempotent — safe
to re-run.

This automates the old manual-symlink process (same resulting layout) — see
[decisions](decisions.md) for why plain symlinks were kept over GNU Stow
(stow's per-file fan-out model doesn't fit this repo's flat layout; tested and
rejected).

Linked dirs (`~/.config/<name>` ← `~/dotfiles/<name>`): `hypr`, `kitty`,
`nvim`, `kanata`, `waybar`, `yazi`, `darkman`, `lazygit`, `sioyek`, `zathura`,
`systemd`. Plus the direct zsh links above. Plus the shared CLI agent
instructions: `instructions.md` → `~/.claude/CLAUDE.md`,
`~/.config/opencode/AGENTS.md`, `~/.codex/AGENTS.md` (see [global](global.md)).
Plus one skill link: `.claude/skills/commit` → `~/.codex/skills/commit`.

✅ 2026-08-08: the `/commit` skill reaches all three agents, but only Codex
needs a symlink. Claude Code reads the project's `.claude/skills/` natively, and
opencode scans `.claude/skills/<name>/SKILL.md` as one of its own project skill
paths — verified with `opencode debug skill`, which lists the skill at its
dotfiles path. Codex discovers skills in `$CODEX_HOME/skills` only and has no
project-level scope, hence the link. ⚠️ **Gotcha**: that makes the skill visible
in _every_ repo under Codex, where its component taxonomy would be wrong — so
the skill body opens with a guard that stops it outside this repo.

✅ 2026-08-08: this repo's own rules are a single file, `../CLAUDE.md`, with
`AGENTS.md` a symlink to it. Before this, `CLAUDE.md` was a note saying "the
real instructions are in AGENTS.md, read it" — Claude Code auto-loads only
`CLAUDE.md`, so a session started knowing nothing about the wiki rules and had
to spend a tool call, or silently skipped them. A symlink resolves for every
tool: Claude Code loads `CLAUDE.md`, Codex and opencode read `AGENTS.md` by
convention, all three get the same bytes. Git tracks the symlink, so a clone
already has it; `bootstrap.sh` re-links it only to repair a clobbered file. The
target is relative so it survives cloning to another path.

✅ fixed 2026-07-01: legacy symlinks `~/.config/tmux` and `~/.config/wezterm`
(both pointed into dotfiles) were removed — the switch to kitty native sessions is
complete (see [decisions](decisions.md)). The `tmux/`/`wezterm/` directories in the repo
were left untouched.

## Packages

Checked by `bootstrap.sh --check`: `hyprland`, `kanata` (AUR), `kitty`,
`helium-browser` (`helium-browser-bin`, AUR), `waybar`, `yazi`, `neovim`,
`zsh`, `zoxide`, `fzf`, `darkman` (AUR), `lazygit`, `sioyek`, `zathura`,
`yt-dlp`, `brotab`, `aichat` (AUR), `taskwarrior`, `copyq`, `python`.
`oh-my-zsh` is auto-installed from zshrc on first run, not checked by the
script.

TODO: exact pacman vs AUR package names and versions for a few entries — not
fully recorded (check during deployment).

## Manual setup outside the repo (TODO clarify)

- Helium extension/native-messaging setup for `brotab` (bookmarks.sh focuses
  existing tabs), see [scripts](scripts.md). `bt install` only writes the
  standard Chromium/Chrome/Brave paths, so Helium may also need the
  `brotab_mediator.json` manifest copied or linked into
  `~/.config/net.imput.helium/NativeMessagingHosts/`.
- XDG default browser is not managed by bootstrap; set `helium.desktop` for
  `http`, `https`, and `text/html` outside the repo if `xdg-open` users should
  follow the migration.
- systemd user services from `~/.config/systemd`.
- Layouts: kanata (see [keymap](keymap.md)). The old `im-select` in [zsh](zsh.md)
  (Windows path) removed 2026-07-01.
- oh-my-zsh and custom plugins are pulled in automatically on the first run of
  zshrc (no install script needed).

✅ fixed 2026-07-01: secrets (`OPENROUTER_API_KEY`, `TODOIST_API_TOKEN`)
removed from `../zsh/zshrc`. The keys remain in git history — rotate them
(see [zsh](zsh.md)).
