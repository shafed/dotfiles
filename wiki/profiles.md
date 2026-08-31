---
title: profiles
type: topic
updated: 2026-08-31
covers:
  - profiles/
  - machines/
  - scripts/dots-state.py
---

# Profiles and desired machine state

Profiles describe *what a machine should be* rather than duplicating bootstrap
logic. `base` owns shared shell/editor tools; `desktop` adds the graphical
Hyprland/Quickshell stack; `laptop`, `gaming` and `ai` compose on top and are
small extension points for hardware/workload-specific requirements.

A machine file is intentionally small. `dots` looks for
`machines/<hostname>.toml`, falling back to `machines/default.toml`; the machine
selects profiles and can add/disable explicit capabilities. Links, managed
files, packages, user services, runtime generators and system prerequisites stay
in profiles so machines cannot drift through copied lists.

Capabilities are descriptive facts used to explain/extend the desired state,
for example `desktop`, `bluetooth`, `battery`, `laptop`, `gaming` and `ai`.
Machine-specific facts belong in `machines/`; application configuration itself
should stay shared unless the machine genuinely needs a different value.

The profile TOML files are the only desired-state manifest. The older package,
link and service arrays were removed from `scripts/dots-lib.sh`; that file now
only contains public CLI metadata. As a result `plan`, `apply`, `doctor` and
`provision` cannot silently consult different dependency lists.

`dots plan` resolves profile includes and compares the selected desired state
with the machine. It is observational: safe migrations run in check mode and
runtime generators are rendered in a temporary HOME. `--json` exposes the same
state for Quickshell or agents. Each dependency/prerequisite declaration carries
a reason so doctor/provision can explain why it exists rather than only naming a
package.

`dots apply` consumes exactly that plan. It converges both missing desired state
and unambiguous repo-owned leftovers from profiles that are no longer selected.
A symlink is removable as extra only while it still points to its known tracked
source; a managed regular file is removable only while its content still equals
the known profile-owned content. This keeps profile switching useful without
turning it into arbitrary `$HOME` cleanup.

Runtime generator declarations include explicit outputs. The engine renders the
same seeded input twice in isolated HOMEs: a nondeterministic generator is a
blocker, while a deterministic mismatch becomes an ordinary planned change.
Tracked theme/Telegram generation is additionally checked by `dots check`/CI.

A changing apply records profiles, capabilities, changes, backups and post-state
under `$XDG_STATE_HOME/dotfiles/runs/`. `dots rollback <run>` can then restore
only the dotfiles-owned paths from that run, provided those paths have not been
changed again since the apply.

External installation remains opt-in. `dots provision` reads the same package
and prerequisite declarations but normal `dots apply` never installs packages
or enables system services. The current provision backend is deliberately Arch
only; a package-manager portability layer should be added only when an actual
second distribution needs it.
