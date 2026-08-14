---
title: bootstrap
type: topic
updated: 2026-08-09
covers:
  - bootstrap.sh
  - zsh/zshrc
  - zsh/zprofile
---

# Bootstrap — deploying on a new machine

Platform: Arch Linux + Hyprland. The Windows/WSL part is removed (see
[decisions](decisions.md)). Session autostart — `../zsh/zprofile`: on tty1 with no
`$DISPLAY`, runs `exec uwsm start hyprland-uwsm.desktop` (not the raw
`start-hyprland` binary) — uwsm wraps Hyprland in a proper systemd user
session so `graphical-session.target` and the session environment are
available to user services; see [hypr](hypr.md) for why this matters.

## Deployment mechanism

Run `./bootstrap.sh` from the repo root. It checks for required commands
(report-only — see [decisions](decisions.md) for why not auto-install), then
`ln -sfvn`s each top-level config dir as a whole into `~/.config/<name>`, plus
`zsh/zshrc` → `~/.zshrc` and `zsh/zprofile` → `~/.zprofile`. Idempotent — safe
to re-run.

This automates the old manual-symlink process (same resulting layout) — see
[decisions](decisions.md) for why plain symlinks were kept over GNU Stow
(stow's per-file fan-out model doesn't fit this repo's flat layout; tested and
rejected).

Linked dirs (`~/.config/<name>` ← `~/dotfiles/<name>`): `hypr`, `kitty`,
`nvim`, `kanata`, `waybar`, `yazi`, `darkman`, `lazygit`, `sioyek`, `zathura`,
`systemd`. Plus the direct zsh links above. Plus the shared CLI agent
instructions: `instructions.md` → `~/.claude/CLAUDE.md`,
`~/.config/opencode/AGENTS.md`, `~/.codex/AGENTS.md` (see [global](global.md)).
Plus one hook script — `.claude/hooks/no-coauthor.sh` → `~/.claude/hooks/` —
because the rule it enforces is global, not repo-scoped. ⚠️ **Gotcha**: only the
script is linked; the `hooks` block registering it lives in the untracked
`~/.claude/settings.json` and won't come back on a fresh machine.
Plus the Claude Code theme: `.claude/themes/gruvbox-material.json` →
`~/.claude/themes/gruvbox-material.json` (the live `~/.claude/settings.json`
references it as `"theme": "custom:gruvbox-material"`).

Besides symlinks, `bootstrap.sh` also **generates two wrappers** into
`~/.local/bin`: `sudo` (routes to `scripts/sudo-notify.sh`) and `sioyek` (pins
the viewer to XWayland — see [sioyek](sioyek.md) for why an alias can't do the
job). ⚠️ **Gotcha**: `~/.local/bin` is on the interactive shell's `PATH` but
**not** on the systemd user session's, so anything launched from a `.desktop`
entry must call these wrappers by absolute path.

✅ 2026-08-08: skills reach all three agents without leaving the repo, so
`bootstrap.sh` links nothing into `$HOME` for them. Claude Code and opencode
both scan the project's `.claude/skills/`; Codex scans the project's
`.agents/skills/`. Verified per tool rather than assumed — `opencode debug
skill` and `codex debug prompt-input` each list the skill at its real path.

The two trees hold **separate copies**, not symlinks, because the frontmatter
differs: `.claude/skills/commit` declares `model: haiku` so mechanical work runs
on a cheap model, and Codex has no equivalent — `name` and `description` are the
only fields it reads (confirmed against its docs and its own `skill-creator`),
and `agents/openai.yaml` adds only UI and invocation policy. A Codex skill runs
on whatever the session runs on, set by `model` / `model_reasoning_effort` in
`~/.codex/config.toml`. Codex would load the Claude file fine — unknown
frontmatter keys are ignored, which was tested — so the copies buy honesty, not
function. ⚠️ **Gotcha**: the bodies must be edited together and nothing enforces
it. They are identical except for **one paragraph**: the Claude copy names
`$ARGUMENTS`, which Codex does not expand, so the Codex copy says "any hint the
user typed after the command" instead. Diff the two with the frontmatter and
that paragraph excluded; anything else that differs is drift.

This is not hypothetical — `1ee2d84` merged a change that taught the skill to
stage untracked files into the Claude copy only. Git reported no conflict (only
one side had touched that path), and the two skills disagreed about whether new
files get committed until it was caught by hand.

⚠️ **Gotcha**: `.agents/` is Codex's namespace, easy to miss because
`~/.codex/skills/` also works. Prefer the in-repo path — the global one makes
every skill visible in _every_ repo, where a taxonomy built for this flat
layout is wrong.

✅ 2026-08-08: this repo's own rules are a single file, `../CLAUDE.md`, with
`AGENTS.md` a symlink to it. Before this, `CLAUDE.md` was a note saying "the
real instructions are in AGENTS.md, read it" — Claude Code auto-loads only
`CLAUDE.md`, so a session started knowing nothing about the wiki rules and had
to spend a tool call, or silently skipped them. A symlink resolves for every
tool: Claude Code loads `CLAUDE.md`, Codex and opencode read `AGENTS.md` by
convention, all three get the same bytes. Git tracks the symlink, so a clone
already has it; `bootstrap.sh` re-links it only to repair a clobbered file. The
target is relative so it survives cloning to another path.

✅ fixed 2026-07-01: legacy symlinks `~/.config/tmux` and `~/.config/wezterm`
(both pointed into dotfiles) were removed — the switch to kitty native sessions is
complete (see [decisions](decisions.md)). The `tmux/`/`wezterm/` directories in the repo
were left untouched.

## Packages

Checked by `bootstrap.sh --check`: `hyprland`, `kanata` (AUR), `kitty`,
`helium-browser` (`helium-browser-bin`, AUR), `waybar`, `yazi`, `neovim`,
`zsh`, `zoxide`, `fzf`, `darkman` (AUR), `lazygit`, `sioyek`, `zathura`,
`yt-dlp`, `brotab`, `aichat` (AUR), `taskwarrior`, `copyq`, `python`.
`oh-my-zsh` is auto-installed from zshrc on first run, not checked by the
script.

TODO: exact pacman vs AUR package names and versions for a few entries — not
fully recorded (check during deployment).

## Manual setup outside the repo (TODO clarify)

- Helium extension/native-messaging setup for `brotab` (bookmarks.sh focuses
  existing tabs), see [scripts](scripts.md). `bt install` only writes the
  standard Chromium/Chrome/Brave paths, so Helium may also need the
  `brotab_mediator.json` manifest copied or linked into
  `~/.config/net.imput.helium/NativeMessagingHosts/`.
- XDG default browser is not managed by bootstrap; set `helium.desktop` for
  `http`, `https`, and `text/html` outside the repo if `xdg-open` users should
  follow the migration.
- systemd user services from `~/.config/systemd`.
- Layouts: kanata (see [keymap](keymap.md)). The old `im-select` in [zsh](zsh.md)
  (Windows path) removed 2026-07-01.
- oh-my-zsh and custom plugins are pulled in automatically on the first run of
  zshrc (no install script needed).

✅ fixed 2026-07-01: secrets (`OPENROUTER_API_KEY`, `TODOIST_API_TOKEN`)
removed from `../zsh/zshrc`. The keys remain in git history — rotate them
(see [zsh](zsh.md)).
