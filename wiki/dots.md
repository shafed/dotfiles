# dots — one entrypoint for repository operations

`dots` is executable directly from the checkout. `./dots apply` is the normal
convergence entrypoint and no separate bootstrap wrapper is required. Desired
machine state lives in [profiles](profiles.md), not in shell arrays.
`scripts/dots-lib.sh` contains public CLI metadata, including canonical command
names and aliases, so help, alias lookup and shell completion share one source
of truth. Packages, links, services, generators and prerequisites remain in the
profile manifests.

## Plan and apply

`dots plan` and `dots apply` resolve state through the same
`scripts/dots-state.py` engine. `dots plan --json` is the stable machine-readable
preview for Quickshell and agents. It reports selected machine/profiles,
capabilities, dependency reasons, blockers and every managed
file/link/generator/service/migration change.

Plan is read-only. Runtime generators are rendered in an isolated temporary HOME
and safe migrations run only in check mode. An unmanaged real file or directory
remains a blocker unless an explicit migration owns it.

Apply is ordered as plan/preflight → backup → changes → refresh → doctor. It
executes the plan created by the same state engine. Existing managed paths that
will be replaced or removed are backed up before mutation. A managed component
from another known profile is removed only when ownership is unambiguous: a
symlink must still point to the tracked source and a managed regular file must
still equal the content owned by that profile.

Selected user services are part of convergence, not just doctor diagnostics. If
a profile service is not enabled, plan shows a `service enable` action; full
apply reloads the user manager and runs `systemctl --user enable --now`. Services
owned only by a profile that is no longer selected are disabled. This lets a
fresh machine reach the same service state without a separate bootstrap step.

A repeated apply is a real no-op. With no primary drift it does not rewrite
wrappers, rerun generators, clear Quickshell cache, restart services or create a
history entry. A normal full no-op still runs doctor because packages or system
prerequisites may drift independently of dotfiles-owned files.

`--links-only` exists for testing and targeted convergence and applies only
managed links/files; it deliberately skips runtime generators, migrations and
service operations.

## Drift

`dots plan` answers “what would apply change now?”. `dots drift` answers the
broader “how does this machine differ from the manifest?”. It includes the
managed plan plus missing required/optional packages, explicitly installed Arch
packages that are not declared by the selected profiles, and enabled local user
services outside the manifest.

Extras are informational. `dots drift` does not uninstall packages or disable an
unknown service. Required managed/package drift affects the exit status;
`extra_explicit_packages` and `unexpected_user_services` do not. Use
`dots drift --json` for agents/UI.

## Provisioning

Package installation is intentionally outside normal apply. `dots provision`
reads the same profile package and system-prerequisite declarations, calculates
one action list, then either shows or executes that list.

`dots provision --dry-run` is the required safe preview. It prints exact pacman,
AUR, `uv tool` and `systemctl enable --now` commands and executes none of them.
If the declared installer is unavailable or unsupported, provision reports a
blocker and stops instead of guessing. `--yes` skips the interactive confirmation
for the real run; `--json` exposes the dry-run/action plan for automation.

The supported installation methods are deliberately only the ones currently
used by manifests: Arch repository packages via pacman, AUR via an installed
`paru` or `yay`, isolated CLI tools via `uv tool`, and declared system services
via systemctl. Other backends should be added only when a real manifest requires
them.

The intended fresh-machine flow is:

```text
./dots plan
./dots provision --dry-run
./dots provision
./dots apply
./dots doctor
```

The final proof is another `dots plan`/`dots apply`: both should report no
managed changes.

## History and rollback

Every changing apply creates a JSON run under
`$XDG_STATE_HOME/dotfiles/runs/` (normally
`~/.local/state/dotfiles/runs/`). The record contains commit, timestamp, machine,
profiles, capabilities, the pre-apply JSON plan, changes, backup paths,
post-apply snapshots, status and a structured post-apply doctor result. No-op
applies do not create history.

`dots history` lists apply and rollback runs; `dots show <run>` shows one record
and `dots show <run> --json` exposes the full plan/doctor payload. Existing
managed paths that will be replaced or deleted are copied to the same run ID
under `$XDG_STATE_HOME/dotfiles/backups/`. Direct `dots migrate` keeps its
standalone lazy backup behavior.

`dots rollback <run>` restores only dotfiles-owned paths represented by that
apply. It does not uninstall packages, reverse arbitrary OS state or pretend to
be a filesystem snapshot. Before restoring anything it compares the current
path with the recorded post-apply snapshot; if the path changed later, rollback
refuses rather than overwriting a newer manual edit.

## Doctor

`dots doctor` is profile-aware and reuses the same resolved desired state as
plan. It reports managed drift, missing required/optional packages, declared
system prerequisites and selected user-service runtime state.

Required package/prerequisite failures include the manifest reason; optional
developer tools are warnings. When the systemd user manager is unavailable,
runtime service state is a warning rather than fabricated success.
`dots doctor --json` exposes the same report for UI/agents.

## Generated state and repository checks

Runtime generators declare their outputs in profiles. Plan verifies them in an
isolated temporary HOME without touching the real machine. The same seeded input
is rendered twice; different results are a blocker because apply could never
converge reliably. If the result is deterministic but differs from the real
output, only that stale generator is scheduled.

`dots check generated` verifies tracked generation too. `dots check all` runs
Shell, Lua, Python, generated-state and integration tests. Tests cover profile
inheritance/machine selection/capabilities, JSON plan schema, read-only planning,
blockers, apply no-op, backup-before-replacement, history plan/doctor metadata,
rollback safety, user-service convergence, drift, provisioning, command aliases,
Zsh completion generation and the absence of the removed `stage` command.

## Commands, aliases and completion

Every public abbreviation is declared next to its canonical command in
`scripts/dots-lib.sh`. `dots help` shows aliases beside commands, `dots aliases`
prints an alias → command table, and both `dots commands --json` and
`dots aliases --json` expose the same metadata to tools.

Useful short forms include `pl` (plan), `a` (apply), `dr` (drift), `pv`
(provision), `d` (doctor), `c` (check), `hi`/`hist` (history), `sh` (show), `rb`
(rollback), `rs` (restart), `rf` (refresh), `s` (shell), `p` (panel), `db`
(debug), `ls` (commands), `al` (aliases), `comp` (completion) and `h` (help).
Aliases are resolved from the metadata before dispatch, so `dots help hi` and
`dots hi --json` use exactly the same implementation as `history`.

`dots completion zsh` prints the native completion function. The base profile
links `zsh/completions/_dots` into Oh My Zsh's custom completion directory, so
new shells complete canonical commands, abbreviations, common options and fixed
subcommand values. The existing shell alias `ds=dots` is registered with the
same completion function.

`stage` is intentionally not a public or internal dots feature anymore. Testing
a candidate branch should use an explicitly created Git worktree and run
`./dots check all` / `./dots plan` there rather than hiding that lifecycle behind
a CLI command.

`restart` owns routine managed user-service restarts. `refresh` rebuilds derived
state. `dots shell` / `dots panel` expose the stable Quickshell control surface;
raw arbitrary Quickshell IPC is not public `dots` API. `debug` remains
observational and can omit journal text with `--no-logs`.
