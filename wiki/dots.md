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
  - scripts/dots-rollback.sh
  - scripts/dots-provision.sh
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

`dots` is executable directly from the checkout. `./dots apply` is the normal
convergence entrypoint; `bootstrap.sh` remains only as a compatibility wrapper.
Desired machine state lives in [profiles](profiles.md), not in shell arrays.
`scripts/dots-lib.sh` now contains only public CLI metadata, so packages, links,
services, generators and prerequisites have one source of truth.

## Plan and apply

`dots plan` and `dots apply` resolve state through the same
`scripts/dots-state.py` engine. `dots plan --json` is the read-only form for
Quickshell and agents. It reports profile selection, capabilities, dependency
reasons, blockers and each file/link/generator/service/migration change.

Apply is ordered as plan/preflight → backup → changes → refresh → doctor. Safe
migrations therefore happen before a colliding desired symlink is installed.
An unmanaged real file or directory remains a blocker unless an explicit
migration owns it. A managed component from another known profile is removed
only when ownership is unambiguous: a symlink must still resolve to the tracked
repo source, and a generated managed file must still exactly equal the content
owned by that profile. Unrelated user files are not garbage-collected.

A repeated apply is a real no-op. With no primary drift it does not rewrite
wrappers, rerun generators, clear Quickshell cache, restart services or create a
history entry. A normal full no-op still runs doctor, because external packages
or system prerequisites may have drifted independently of dotfiles files.

`--links-only` exists for bootstrap/testing and applies only managed links/files;
it deliberately skips runtime generators, migrations, service operations and
doctor.

## History and rollback

Every changing apply creates a JSON run under
`$XDG_STATE_HOME/dotfiles/runs/` (normally
`~/.local/state/dotfiles/runs/`). The record is created before mutation and
contains commit, machine, profiles, capabilities, planned changes, backups,
post-apply snapshots and status. Migration/generator failures are therefore
recorded as failed runs instead of disappearing between plan and history.

`dots history` lists apply and rollback runs; `dots show <run>` shows one record.
Existing managed paths that will be replaced or deleted are copied to the same
run ID under `$XDG_STATE_HOME/dotfiles/backups/`. Direct `dots migrate` keeps its
standalone lazy backup behavior.

`dots rollback <run>` restores only dotfiles-owned paths represented by that
apply: files, symlinks and declared generator outputs. It deliberately does not
try to uninstall packages, reverse arbitrary OS state or provide a filesystem
snapshot. Before restoring anything it compares the current path with the
post-apply snapshot; if the path changed later, rollback refuses rather than
overwriting a newer manual edit. A successful rollback is itself recorded and
the original apply is marked with its rollback run ID.

## Doctor

`dots doctor` is profile-aware. It reuses the same resolved state as plan and
reports both directions of drift: missing/wrong desired components and known
repo-owned components left behind from an unselected profile. Required package
or prerequisite failures include the profile reason; optional developer tools
are warnings. `dots doctor --json` exposes the same report for UI/agents.

User-service checks remain runtime-aware. When the systemd user manager is
available, selected services must be enabled and the core graphical services
must be active during an active graphical session. If the user manager is not
available (for example from a minimal test HOME/CI context), runtime service
state is a warning rather than fabricated success.

## Generated state and repository checks

Runtime generators declare their outputs in profiles. Plan verifies them in an
isolated temporary HOME without touching the real machine. The same seeded input
is rendered twice; different results are a blocker because apply could never
converge reliably. If the result is deterministic but differs from the real
output, only that stale generator is scheduled.

`dots check generated` also verifies tracked generation. The shared Gruvbox
palette generator must match its tracked outputs, and both it and the Telegram
renderer are checked for deterministic output. `dots check all` includes these
checks, so the existing CI workflow gains reproducibility/stale-generated
coverage without a separate CI implementation.

## Provisioning

Package installation is intentionally outside normal apply. `dots provision` is
an explicit new-machine operation that consumes the same profile package and
system-prerequisite declarations. `dots provision --check` only reports what is
missing; `--yes` skips the interactive confirmation.

Only the real Arch backend is implemented now: repository packages use pacman,
AUR packages use an installed `paru` or `yay`, and isolated CLI tools use
`uv tool`. System prerequisites currently use `systemctl enable --now`. Other
distribution backends are intentionally deferred until a real second OS needs
them; application configs do not depend on a package-manager portability layer.

The intended fresh-machine flow is therefore:

```text
dots provision   # opt-in external packages/system prerequisites
dots plan        # inspect dotfiles drift
dots apply       # converge dotfiles-owned state
dots doctor      # verify final profile state
```

## Other commands

The command catalog is data: `dots commands --json` exposes the same stable
public names/usage strings as help. Useful explicit abbreviations include `pl`
(plan), `a` (apply), `d` (doctor), `c` (check), `hist` (history), `rb`
(rollback), `pv` (provision), `rs` (restart), `rf` (refresh), `s` (shell), `p`
(panel), `db` (debug), `ls` (commands), and `h` (help).

`restart` owns routine managed user-service restarts. `refresh` rebuilds derived
state. `dots shell` / `dots panel` expose the stable Quickshell control surface;
raw arbitrary Quickshell IPC is not public `dots` API. `debug` remains
observational and can omit journal text with `--no-logs`.

Waybar remains a retired-component migration. An old managed Waybar symlink is
backed up before removal; stale cache is derived state and removed without
backup; an unmanaged real config remains untouched and blocks automatic
convergence.
