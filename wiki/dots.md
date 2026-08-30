---
title: dots
type: topic
updated: 2026-08-30
covers:
  - dots
  - bootstrap.sh
  - scripts/dots-lib.sh
  - scripts/dots-apply.sh
  - scripts/dots-doctor.sh
  - scripts/dots-check.sh
  - scripts/dots-migrate.sh
  - scripts/dots-theme.sh
  - scripts/dots-commands.sh
  - scripts/dots-restart.sh
  - scripts/dots-refresh.sh
  - scripts/dots-shell.sh
  - scripts/dots-debug.sh
  - tests/dots.sh
  - .pre-commit-config.yaml
  - .github/workflows/check.yml
---

# dots — one entrypoint for repository operations

`dots` is executable directly from the checkout, so there is no bootstrap
chicken-and-egg problem. `./dots apply` is the deployment entrypoint on a fresh
machine and also the convergence command on an existing one. It installs the
managed links (including `~/.local/bin/dots`), applies migrations, invalidates
derived Quickshell state, refreshes already-running managed user services, then
finishes with `doctor`. `bootstrap.sh` is only a compatibility wrapper around
that command.

Package installation deliberately remains outside `apply`. Missing required
commands are reported before changes and remain `doctor` errors at the end; this
keeps a personal dotfiles checkout from becoming a second package manager while
still allowing links to be installed before every desktop package is present.

`apply` does not replace an existing real file or directory at a managed link
path. It may repair or replace a symlink, but an unmanaged path is a hard stop
with a request to move/archive it first. Repeated convergence therefore does not
turn "make it look like the repo" into permission to delete local state.

Service refresh during `apply` uses `systemctl --user try-restart`, not
`restart`. On a newly provisioned TTY this avoids starting Quickshell before the
graphical session has exported its Wayland/session environment. The generated
Quickshell cache is still removed, so the next legitimate start rebuilds the
current modular QML tree from tracked sources.

`doctor` checks machine state; `check` checks repository state. Missing desktop
packages are a useful `doctor` failure but should not make source-tree syntax
checks depend on a complete Hyprland installation. Pre-commit and CI therefore
run the same Shell, Lua, Python and CLI-test primitives through `dots check`.

The command catalog is also data: `dots commands --json` exposes the same names,
usage strings and descriptions used by human help. This is intentionally much
smaller than discovering arbitrary executable files, so agents can inspect the
supported surface without turning every helper into public API.

`restart` owns routine user-service restarts for Quickshell, Kanata and darkman.
`refresh` rebuilds derived state instead of restoring tracked configs. In
particular, `dots refresh quickshell` removes
`$XDG_CACHE_HOME/dots-shell/quickshell` and restarts the service so the runtime
is copied again from the tracked modular Quickshell source.

Manual shell control goes through `dots shell` / `dots panel`. These commands
whitelist stable actions from `quickshell/dots-shell`, including Applications,
Bookmarks, Clipboard, Hotkeys, the compact System overview and the detailed
system panels. Raw arbitrary Quickshell IPC is not part of the public `dots`
contract. `dots shell refresh` refreshes live shell data; `dots refresh
quickshell` rebuilds the generated runtime.

`debug` is a compact support bundle: repository revision, session information,
component versions, managed service state, doctor failures/warnings, and by
default recent Quickshell journal lines. It is observational only; use
`--no-logs` before pasting output somewhere that should not receive journal
text.

`migrate` is intentionally idempotent and has no migration database. A migration
exists only while obsolete state can be detected directly. Before a migration
changes or removes an existing user file/config, that path is copied with
metadata and symlink identity preserved into a lazily-created run directory
under `$XDG_STATE_HOME/dotfiles/backups/`, or
`~/.local/state/dotfiles/backups/` when `XDG_STATE_HOME` is unset. The command
prints the exact source and backup paths. `--check`, no-op runs, cache cleanup,
service changes, and unmanaged configs that are only reported do not create a
backup directory. There is deliberately no snapshot/rollback framework: these
are transparent copies for manual recovery if needed. `dots apply` uses the
same migration path and therefore gets the same protection.

Waybar is the first migration. Quickshell owns the active bar, so a running or
enabled Waybar, `~/.config/waybar`, Waybar cache, or the old tracked
`waybar/config.jsonc` is stale runtime state. An old managed Waybar symlink is
backed up before removal; stale cache is removed without backup because it is
derived state, while an unmanaged real config is reported and left untouched.
`waybar/colors.css` and `waybar/style.css` may remain tracked because the shared
palette generator still owns them as generated compatibility/theme surfaces;
they are not linked by `dots apply` and do not make Waybar an active component.

⚠️ `dots doctor` treats missing required commands and broken managed links as
errors, while developer-only tools such as `luac` and `pre-commit` are warnings.
`dots check` is stricter: if the tool needed for a requested source check is
absent, that check fails rather than pretending the source was validated.
