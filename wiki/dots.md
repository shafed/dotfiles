---
title: dots
type: topic
updated: 2026-08-30
covers:
  - dots
  - scripts/dots-lib.sh
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

`dots` is deliberately a thin dispatcher rather than a second configuration
system. `bootstrap.sh` remains the installer because it has to work before the
CLI is installed; bootstrap then links the repository's `dots` into
`~/.local/bin`. Package and link manifests live in `scripts/dots-lib.sh` so
bootstrap and diagnostics cannot silently disagree about what a valid install
looks like.

`doctor` checks machine state; `check` checks repository state. Keeping those
separate matters on a fresh machine: missing desktop packages are a useful
`doctor` failure but should not make a source-tree syntax check depend on a full
Hyprland installation. The local pre-commit hooks and CI therefore run the same
`dots check` primitives for Shell, Lua, Python and the CLI's own tests.

The command catalog is also data: `dots commands --json` exposes the same names,
usage strings and descriptions used by human help. This is intentionally much
smaller than discovering arbitrary executable files — agents can inspect the
supported surface without turning every helper script into public API.

`restart` owns the routine systemd-user restart spelling for Quickshell, Kanata
and darkman. `refresh` is narrower: it rebuilds derived state rather than
restoring tracked configs. In particular, `dots refresh quickshell` removes the
generated runtime under `$XDG_CACHE_HOME/dots-shell/quickshell` and restarts the
service so `start.sh` regenerates it from tracked sources; it never copies a
"default" config over the repository.

Manual desktop-shell control should go through `dots shell` / `dots panel`.
Those commands deliberately whitelist the stable actions already implemented by
`quickshell/dots-shell` instead of exposing raw arbitrary IPC as part of the
public CLI. `dots shell refresh` refreshes live shell data through IPC, while
`dots refresh quickshell` rebuilds the generated runtime; the similar names have
different scopes on purpose.

`debug` is a compact support bundle: repository revision, session information,
component versions, managed service state, doctor failures/warnings, and by
default the last Quickshell journal lines. It is observational only. Use
`--no-logs` when output will be pasted somewhere that should not receive recent
journal text.

`migrate` is intentionally idempotent and has no migration database. A migration
exists only while an obsolete state can be detected directly. This avoids a
second source of truth for machine history. Before a migration deletes or
changes an existing user file/config, it first copies that path with metadata
and symlink identity preserved into a lazily-created run directory under
`$XDG_STATE_HOME/dotfiles/backups/` when `XDG_STATE_HOME` is set, otherwise
`~/.local/state/dotfiles/backups/`, and prints the exact source and backup paths.
`--check`, no-op runs, cache cleanup, service changes, and unmanaged configs that
are only reported do not create backups. There is no automatic rollback layer;
a backup is just a transparent copy to restore manually if needed.

Waybar is the first such migration. Quickshell owns the bar, so a running or
enabled Waybar, `~/.config/waybar`, or Waybar cache is stale state. The retired
managed `~/.config/waybar` symlink is backed up before removal; stale Waybar
cache is removed without backup because it is derived state. An unmanaged real
Waybar config is still reported for manual archival instead of being touched.
The old tracked `waybar/` directory was removed as part of introducing this
contract. The Quickshell startup kill remains as compatibility insurance for
machines that have not migrated yet; it is not evidence that Waybar is still a
supported component.

⚠️ Gotcha: `dots doctor` treats missing required commands and broken managed
links as errors, while developer-only tools such as `luac` and `pre-commit` are
warnings. `dots check` is stricter: if the tool needed for a requested source
check is absent, that check fails rather than pretending the source was
validated.
