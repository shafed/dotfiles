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

Profiles exist so a new machine can describe *what it is* instead of growing a
second copy of bootstrap logic. `base` owns shared shell/editor tools;
`desktop` adds the graphical Hyprland/Quickshell stack; `laptop`, `gaming` and
`ai` compose on top and are the extension points for hardware/workload-specific
requirements.

A machine file is intentionally small. `dots` looks for
`machines/<hostname>.toml`, falling back to `machines/default.toml`, and the
file only selects profiles plus explicit capabilities. Package, link, service
and generator declarations stay in profiles so two machines do not drift by
copy/paste.

`dots plan` resolves the same desired state as `dots apply`. It is observational:
symlinks and managed files are compared directly, migrations run in check mode,
and legacy runtime generators are executed against a temporary HOME before
their declared outputs are compared. `--json` exposes the same plan for
Quickshell or agents. Missing packages are reported with the profile reason but
are not installed by apply.

`dots apply` consumes that plan. A run with no machine changes does not rewrite
wrappers, rerun runtime generators, clear Quickshell cache, or restart services;
it only runs the final doctor. A changing run is recorded under
`$XDG_STATE_HOME/dotfiles/runs/` with the repository commit, selected profiles,
capabilities, planned changes and any backup paths. `dots history` lists those
runs and `dots show <run>` displays one record.

This is the first convergence milestone only. `doctor` still uses the legacy
package/link arrays in `scripts/dots-lib.sh`; moving those checks to the profile
model, adding rollback, reproducibility checks and `dots provision` are later
steps so they do not get mixed into the initial plan/apply engine change.
