---
title: bootstrap
type: topic
updated: 2026-08-30
covers:
  - bootstrap.sh
  - dots
  - scripts/dots-apply.sh
  - scripts/dots-lib.sh
  - zsh/zprofile
---

# Bootstrap — deploying on a new machine

Arch Linux + Hyprland. The primary fresh-machine command is now `./dots apply`
from the repo root. `dots` is already executable inside the checkout, so a
separate installer is unnecessary; the apply pass links itself into
`~/.local/bin` for subsequent use. `bootstrap.sh` remains only so old muscle
memory/scripts keep working — it forwards its arguments to `dots apply`, and
legacy `--check` / `--link` are accepted there.

`apply` reports missing required packages but never installs them
([decisions](decisions.md)). It then converges managed symlinks, migrations and
derived runtime state and finishes with [dots doctor](dots.md). Existing real
files/directories at managed destinations are never deleted or overwritten;
move/archive such a conflict explicitly and rerun.

The required-package and managed-link manifests are shared with `dots doctor`.
This is intentional: adding a deployment-managed component in one place must not
leave diagnostics describing a different machine. XDG config/data roots are
honored rather than assuming `~/.config` and `~/.local/share` for those classes
of link.

Session autostart is `../zsh/zprofile`: on tty1 with no `$DISPLAY` it runs
`exec uwsm start hyprland-uwsm.desktop` rather than the raw `start-hyprland`
binary, because uwsm wraps Hyprland in a real systemd user session — without it
`graphical-session.target` and the session environment never become available to
user services ([hypr](hypr.md)).

## What apply manages beyond the config dirs

Read `scripts/dots-apply.sh` and the manifests in `scripts/dots-lib.sh` for the
current list. Three things are not obvious from the link list itself:

- ⚠️ **The `no-coauthor` hook is only half-installed by design.** `apply` links
  `.claude/hooks/no-coauthor.sh` into `~/.claude/hooks/`, but the `hooks` block
  that *registers* it lives in `~/.claude/settings.json` — machine state,
  untracked, a real file rather than a symlink. A fresh machine gets the script
  and no registration, so the guard silently never fires ([global](global.md)).
- ⚠️ **`~/.local/bin` is on the interactive shell's `PATH` but not the systemd
  user session's.** `apply` installs `dots` there and generates two wrappers —
  `sudo` (notifies on a background password prompt) and `sioyek` (pins the
  viewer to XWayland, [sioyek](sioyek.md)). Anything launched from a `.desktop`
  entry must call wrappers by absolute path or it silently gets the unwrapped
  binary.
- oh-my-zsh and its plugins are **not** checked or installed here — zshrc clones
  them on first run ([zsh](zsh.md)).

`apply` invalidates the generated Quickshell runtime but only **try-restarts**
managed services. This prevents a deployment from starting Quickshell outside a
graphical session with no Wayland environment; inactive services consume the
new config on their next normal start.

## Skills reach all three agents without leaving the repo

Claude Code and opencode both scan the project's `.claude/skills/`; Codex scans
`.agents/skills/`. Verified per tool rather than assumed (`opencode debug skill`,
`codex debug prompt-input`). So deployment links nothing into `$HOME` for
skills.

The two trees hold **separate copies, not symlinks**, because the frontmatter
differs — `.claude/skills/commit` declares `model: haiku` and Codex has no
equivalent. Codex would load the Claude file fine (unknown keys are ignored,
tested), so the copies buy honesty, not function.

⚠️ **Gotcha**: the bodies must be edited together and nothing enforces it. They
are identical except for one paragraph — the Claude copy names `$ARGUMENTS`,
which Codex does not expand. Diff the two with the frontmatter and that
paragraph excluded; anything else is drift. This is not hypothetical: `1ee2d84`
taught the skill to stage untracked files in the Claude copy only, git reported
no conflict because only one side touched that path, and the two disagreed about
whether new files get committed until someone noticed by hand.

⚠️ **Gotcha**: `.agents/` is Codex's namespace and easy to miss because
`~/.codex/skills/` also works. Prefer the in-repo path — the global one makes
every skill visible in *every* repo, where a taxonomy built for this flat layout
is wrong.

## Manual setup outside the repo

These do not survive a fresh machine and `dots apply` does not cover them:

- Helium extension + native-messaging manifest for `bruvtab` (what lets
  `bookmarks.sh` focus an existing tab, [scripts-pickers](scripts-pickers.md)).
  `bruvtab install` only writes the standard Chromium/Chrome/Brave paths, so
  Helium likely needs `bruvtab_mediator.json` copied into
  `~/.config/net.imput.helium/NativeMessagingHosts/`.
- XDG default browser — set `helium.desktop` for `http`, `https`, `text/html`.
- The `hooks` block in `~/.claude/settings.json` (see above).

Tracked systemd wants are deployed with the `systemd/` config directory;
`dots doctor` verifies the core user units and the Quickshell/Dunst ownership
contract after apply.

TODO: exact pacman vs AUR package names and versions are not fully recorded —
confirm during the next real deployment.
