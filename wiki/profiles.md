---
title: profiles
type: topic
updated: 2026-09-02
covers:
  - profiles/
  - machines/
  - scripts/dots-state.py
  - scripts/dots-machine.py
---

# Profiles and desired machine state

Profiles describe *what a machine should be* rather than duplicating bootstrap
logic. `base` owns shared shell/editor tools, including required `tmux` on every
machine; kitty native sessions remain the primary local session workflow.
`desktop` adds the graphical
Hyprland/Quickshell stack and desktop-wide networking state. Bluetooth is a
separate `bluetooth` profile because a desktop machine does not imply Bluetooth
hardware. `laptop` includes both `desktop` and `bluetooth`, then adds only
laptop-specific battery, TLP power-profile and brightness requirements. The
`hp-envy-x360-13-ay0xxx` hardware profile extends it with the exact AMD Renoir
microcode, AMDGPU/Realtek firmware and Mesa/RADV userspace drivers used by
`arch-laptop`; it deliberately avoids unrelated firmware families and
out-of-tree drivers for devices already supported by the kernel. `ai` remains a
small workload extension point. `documents`, `development`, `networking` and
`storage` keep workload and filesystem tools out of the universal base, while
`printing` owns the CUPS/SANE stack and the Canon MG3600 driver.
The machine-only `hardware-shafed` profile pins the Intel i7-6700 microcode and
the NVIDIA 580xx DKMS/userspace stack required by that desktop's GTX 1060; it is
not shared with the laptop.

`development` contains the shared build toolchain, Lua language server and the
three CLI coding agents. Rust and Kotlin language servers are deliberately not
part of desired state until those languages are actively used; TeX tooling
belongs to `documents` instead.

There is intentionally no empty `gaming` profile. A profile should exist only
when it owns real distinguishing desired state; a future gaming profile can be
added when it has actual packages/services/configuration to declare.

A machine file is intentionally small. `dots` looks for
`machines/<hostname>.toml`, falling back to `machines/default.toml`; the machine
selects profiles and can add/disable explicit capabilities. Links, managed
files, packages, user services, runtime generators and system prerequisites stay
in profiles so machines cannot drift through copied lists.

Capabilities are descriptive facts used to explain or extend state. Current
examples include `base`, `desktop`, `bluetooth`, `laptop`, `battery` and `ai`.
Machine-specific facts belong in `machines/`; shared application configuration
should stay in profiles unless a machine genuinely needs a different value.
`machines/arch-laptop.toml` selects the model-specific hardware profile instead
of letting this hostname silently fall back to the desktop-only default.

A Bluetooth-equipped desktop can select both profiles, for example
`profiles = ["desktop", "bluetooth"]` in its machine file or temporarily with
`dots doctor --profile desktop,bluetooth`. A plain `desktop` profile does not
install `bluez-utils` or require `bluetooth.service`.

The profile TOML files are the only desired-state manifest. Package, link and
service arrays do not exist in `scripts/dots-lib.sh`; that file contains only
public CLI metadata. `plan`, `apply`, `doctor`, `drift` and `provision` therefore
start from the same resolved profile/machine model.

`dots plan` resolves profile includes and compares selected desired state with
the machine. It is observational: safe migrations run in check mode and runtime
generators are rendered in a temporary HOME. `--json` exposes the same plan for
Quickshell or agents. Each dependency/prerequisite declaration carries a reason
so doctor/provision can explain why it exists instead of only naming a package.
Most dependencies are detected by their executable command. Package collections
without a unique executable, such as firmware, microcode, graphics drivers,
LibreOffice language resources and TeX Live collections, use `check = "package"`
and are checked directly in the local pacman database.

`dots apply` uses the same state engine and converges both missing desired state
and unambiguous repo-owned leftovers from profiles that are no longer selected.
A symlink is removable as extra only while it still points to its known tracked
source; a managed regular file is removable only while its content still equals
the known profile-owned content. This permits profile switching without turning
apply into arbitrary `$HOME` cleanup.

`dots drift` is broader than plan. It adds missing packages, explicitly installed
Arch packages outside the manifest and enabled local user services outside the
selected profile. These extras are informational and are never removed
automatically.

External installation remains opt-in. `dots provision --dry-run` calculates the
exact package/system actions from the same profile declarations without running
them. A real `dots provision` executes that action list; normal `dots apply`
never becomes a package manager.

On Arch, `pacman` and `aur` identify whether a manifest entry comes from the
official repositories or AUR; provisioning installs both groups together with
`yay`. This preserves useful source metadata without requiring two separate
transactions.

Runtime generator declarations include explicit outputs. The engine renders the
same seeded input twice in isolated HOMEs: a nondeterministic generator is a
blocker, while a deterministic mismatch becomes an ordinary planned change.
Tracked theme/Telegram generation is additionally checked by `dots check`/CI.

A changing apply records commit, machine, profiles, capabilities, the pre-apply
plan, changes, backups, post-state and doctor result under
`$XDG_STATE_HOME/dotfiles/runs/`. `dots rollback <run>` can restore only the
dotfiles-owned paths from that run when they have not changed again since apply.
