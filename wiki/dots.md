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
with a request to move/archive it first. This makes repeated convergence safe on
an existing machine instead of making "make it look like the repo" permission
to delete local state.

Service refresh during `apply` uses `systemctl --user try-restart`, not
`restart`. That distinction matters on a newly provisioned TTY: Quickshell must
not be started before the graphical session has exported its Wayland/session
environment. The generated Quickshell cache is still removed, so the next
legitimate start rebuilds it from tracked sources.

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
second source of truth for machine history. Destructive cleanup is limited to
safe state such as cache or an old managed symlink; an unmanaged real config is
reported for manual archival instead of being deleted.

Waybar is the first such migration. Quickshell owns the bar, so a running or
enabled Waybar, `~/.config/waybar`, or Waybar cache is stale state. The old
tracked `waybar/` directory was removed as part of introducing this contract.
The Quickshell startup kill remains as compatibility insurance for machines that
have not migrated yet; it is not evidence that Waybar is still a supported
component.

⚠️ Gotcha: `dots doctor` treats missing required commands and broken managed
links as errors, while developer-only tools such as `luac` and `pre-commit` are
warnings. `dots check` is stricter: if the tool needed for a requested source
check is absent, that check fails rather than pretending the source was
validated.
