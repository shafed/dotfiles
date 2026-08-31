---
title: bootstrap
type: topic
updated: 2026-08-31
covers:
  - bootstrap.sh
  - dots
  - profiles/
  - machines/
  - scripts/dots-state.py
  - scripts/dots-apply.sh
  - scripts/dots-provision.sh
  - zsh/zprofile
---

# Bootstrap — deploying on a new machine

The checkout does not need a separate installer: `./dots` runs directly from the
repo and `dots apply` links itself into `~/.local/bin`. `bootstrap.sh` is only a
compatibility wrapper around `dots apply`; legacy `--check` / `--link` continue
to map to the apply surface.

A fresh Arch machine has two deliberately separate phases. External packages
and system prerequisites are opt-in through `./dots provision`; dotfiles-owned
state is converged through `./dots apply`. Keeping those operations separate
means routine apply never unexpectedly invokes sudo, installs packages or
changes system services.

Recommended fresh-machine sequence:

```text
./dots provision --check   # inspect missing external prerequisites
./dots provision           # optional: install/enable them on Arch
./dots plan                # inspect file/link/service/generator drift
./dots apply               # converge dotfiles-owned state
./dots doctor              # verify selected profile including prerequisites
```

The current provisioning backend intentionally supports Arch only. Pacman
packages use `sudo pacman -S --needed`, AUR entries require `paru` or `yay`, and
isolated CLI tools use `uv tool`. Declared system prerequisites such as
NetworkManager/BlueZ/power-profiles-daemon are enabled with systemd. Other distro
backends are deferred until another real machine needs them.

Desired state comes from `profiles/*.toml` plus a small machine selector in
`machines/<hostname>.toml` (falling back to `machines/default.toml`). Packages,
links, services, generators and prerequisites are not duplicated in bootstrap or
doctor. See [profiles](profiles.md) and [dots](dots.md).

`apply` refuses to replace unrelated real files/directories at managed
locations. Safe explicit migrations are planned/backed up before links are
created; otherwise move/archive a blocker yourself and rerun. Repeated apply is
a true no-op when managed state already matches.

Changing applies are recorded in `~/.local/state/dotfiles/runs/`, with backups
under `~/.local/state/dotfiles/backups/`. `dots rollback <run>` can restore only
files, symlinks and declared generated outputs owned by that run. It refuses to
overwrite a path that changed after the apply and does not attempt to uninstall
packages or revert the whole operating system.

## Session launch

Session autostart remains `../zsh/zprofile`: on tty1 with no `$DISPLAY` it runs
`exec uwsm start hyprland-uwsm.desktop`. uwsm wraps Hyprland in a systemd user
session so `graphical-session.target` and the session environment are available
to user services ([hypr](hypr.md)).

## Important state outside automatic convergence

Some state remains intentionally manual or application-owned:

- The `no-coauthor` script is linked into `~/.claude/hooks/`, but registering it
  in `~/.claude/settings.json` is still mutable Claude machine state
  ([global](global.md)).
- `~/.local/bin` is available to the interactive shell but should not be assumed
  to be on every systemd user service PATH. Desktop/service callers that require
  a wrapper should use its absolute path.
- oh-my-zsh and its plugins are still first-run shell state rather than profile
  packages ([zsh](zsh.md)).
- Helium native messaging for `bruvtab` and XDG default-browser selection remain
  application/system integration steps not represented by the current profile.

Tracked systemd user units are linked as part of the desktop profile. A full
apply only try-restarts already-running managed services; it does not start
Quickshell from a non-graphical TTY. Doctor verifies the selected profile after
convergence.

## Agent skills

Claude Code and opencode scan `.claude/skills/`; Codex scans `.agents/skills/`.
The trees remain separate copies because their frontmatter differs. When a skill
body changes, update both copies; nothing currently enforces their semantic
parity.
