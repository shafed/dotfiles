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
