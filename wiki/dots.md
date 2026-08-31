---
title: dots
type: topic
updated: 2026-08-31
covers:
  - dots
  - bootstrap.sh
  - scripts/dots-state.py
  - scripts/dots-lib.sh
  - scripts/dots-plan.sh
  - scripts/dots-apply.sh
  - scripts/dots-history.sh
  - scripts/dots-show.sh
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
  - tests/dots-state.sh
  - .pre-commit-config.yaml
  - .github/workflows/check.yml
---

# dots — one entrypoint for repository operations

`dots` is executable directly from the checkout, so there is no bootstrap
chicken-and-egg problem. `./dots apply` remains the deployment/convergence
entrypoint; `bootstrap.sh` is only a compatibility wrapper around it.

Desired machine state now comes from [profiles](profiles.md). `dots plan` and
`dots apply` both resolve that state through `scripts/dots-state.py`, so preview
and mutation cannot grow separate lists of links, runtime generators or
services. `dots plan --json` is the machine-readable form intended for
Quickshell and agents.

The apply flow is deliberately ordered as preflight/plan → backup → changes →
refresh → doctor. Safe stale-state migrations are part of the plan and run
before managed symlinks are installed, so an old real
`$XDG_DATA_HOME/darkman` can be backed up and removed before the desired
`darkman/scripts` link is created. An unmanaged real Waybar config is still a
blocker because the repository cannot know whether it is safe to delete.

Package installation deliberately remains outside `apply`. The selected
profiles report required and optional commands, packages and reasons, but
missing packages are not installed. A later `dots provision` command is the
place for opt-in package/system prerequisite changes.

Managed symlinks may repair a wrong symlink, but an unrelated real file or
directory is a blocker unless an explicit safe migration owns it. Generated
runtime state such as Helium and CopyQ is checked without touching the real
machine: the generator runs against a temporary HOME and its declared outputs
are compared with current outputs. Only stale generators run during apply.

This makes repeated convergence a real no-op. If the plan contains no machine
changes, apply does not rewrite wrappers, rerun runtime generators, invalidate
Quickshell cache, or restart services. A normal full apply still ends with
`doctor` so a converged repository can report missing external prerequisites.

Service refresh uses `systemctl --user try-restart`, not `restart`. On a newly
provisioned TTY this avoids starting Quickshell before the graphical session has
exported its Wayland/session environment. Quickshell derived cache is removed
only when the plan actually changes managed state.

Changing applies are recorded under
`$XDG_STATE_HOME/dotfiles/runs/` (normally
`~/.local/state/dotfiles/runs/`). A run records the repository commit, selected
machine/profiles/capabilities, the applied plan, status and backup paths.
`dots history` lists changing runs; `dots show <run>` explains one. No-op runs
do not create history entries.

Migration backups live under `$XDG_STATE_HOME/dotfiles/backups/`. When a
migration is executed as part of apply it receives the apply run's backup
directory, so files touched by links/generators and files touched by migrations
belong to one understandable run. Direct `dots migrate` keeps its standalone,
lazily-created backup-directory behavior. Cache cleanup and service operations
do not get backups because they are derived/operational state.

There is not yet an automatic rollback command in this milestone. The history
format and shared backup paths are intentionally the foundation for the next
`dots rollback <run>` step; until then backups remain transparent manual
recovery copies rather than a promise to restore the whole operating system.

`doctor` checks machine state; `check` checks repository state. During this first
profile-engine milestone, doctor still reads the legacy arrays in
`scripts/dots-lib.sh`; moving doctor to the resolved profile and explaining
profile drift is a later step. Pre-commit and CI continue to run Shell, Lua,
Python and CLI tests through `dots check`, now including the state-engine no-op
and history test.

The command catalog is also data: `dots commands --json` exposes the same names,
usage strings and descriptions used by human help. Stable abbreviations include
`pl` (plan), `a` (apply), `d` (doctor), `c` (check), `m` (migrate), `hist`
(history), `t` (theme), `rs` (restart), `rf` (refresh), `s` (shell), `p`
(panel), `db` (debug), `ls` (commands), and `h` (help). They are explicit rather
than inferred from prefixes, so a future command cannot silently change an
existing abbreviation.

`restart` owns routine user-service restarts for Quickshell, Kanata, darkman and
CopyQ. `refresh` rebuilds derived state instead of restoring tracked configs.
Manual shell control goes through `dots shell` / `dots panel`; arbitrary raw
Quickshell IPC is intentionally not part of the public `dots` contract.

`debug` remains observational: it prints repository revision, session/component
information, managed service state, doctor failures/warnings and optionally
recent Quickshell journal lines. Use `--no-logs` when journal text should not be
included in a support bundle.

Waybar remains the primary retired-component migration. An old managed Waybar
symlink is backed up before removal; stale cache is derived state and removed
without backup; an unmanaged real config is reported and left untouched.
Tracked `waybar/colors.css` and `waybar/style.css` can remain compatibility
outputs of the palette generator without making Waybar an active profile
component.

⚠️ `dots doctor` treats missing required commands and broken managed links as
errors, while developer-only tools such as `luac` and `pre-commit` are warnings.
`dots check` is stricter: if a requested source check needs a missing tool, that
check fails instead of pretending the source was validated.
