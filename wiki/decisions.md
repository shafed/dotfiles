---
title: decisions
type: topic
updated: 2026-08-14
---

# decisions — major decisions and rejected alternatives

Key "why it's done this way" page. Each entry:
**decision → reason → rejected alternative → date**.

## Recorded

### Page-status markers (🌱/🚧/✅) removed from the wiki (2026-08-14)
- **Decision**: pages and `index.md` rows no longer carry a completeness marker.
  The `✅ fixed <date>:` entries inside `bootstrap.md`/`zsh.md` stay — those mark
  a specific past problem as resolved, which is content, not page metadata.
- **Reason**: the marker stopped discriminating. 15 of 18 pages were 🚧 —
  `scripts.md` (417 lines, a dozen hard-won gotchas) and `waybar.md` (61 lines of
  overview) carried the identical badge, so it informed no reading decision while
  appearing on every `index.md` row and every page's first line.
- **Reason it was safe to drop now**: the rule that kept the markers current
  ("if the change shifts status 🌱→🚧→✅, fix the row in `index.md`") lived in the
  103-line `CLAUDE.md` deleted in `1add5fc`. Nothing referenced them any more, so
  they were upkeep with no consumer.
- **Rejected**: **re-grounding the marker on a real criterion** (say, "does this
  page cover every file in `covers:`"). That is a judgment call per page per
  edit, and the payoff is a badge — the agent already learns a page's depth by
  reading it, which it must do anyway.
- **Aligned with**: Anthropic's Opus 5 prompting guidance, which is half about
  *removing* inherited scaffolding rather than adding rules.

### Mechanizable rules go into hooks, judgment stays prose (2026-08-09)
- **Decision**: a rule leaves `CLAUDE.md` for a `.claude/hooks/` script only when
  it is checkable **without judgment**. Two moved:
  [../.claude/hooks/wiki-date.sh](../.claude/hooks/wiki-date.sh) (`PostToolUse`
  — sets `updated:` in a wiki page's frontmatter to today) and
  [../.claude/hooks/no-coauthor.sh](../.claude/hooks/no-coauthor.sh)
  (`PreToolUse` — denies a `git commit` whose message carries a
  `Co-Authored-By:` / 🤖 attribution footer). Everything needing judgment —
  what earns an entry here, "record why, not what" — stays in prose.
- **Scope follows the rule, not the file**: the wiki hooks are repo-scoped
  (`.claude/settings.json`), while `no-coauthor.sh` enforces a line from
  `instructions.md` that holds everywhere, so it is registered in
  `~/.claude/settings.json` and linked into `$HOME` by `bootstrap.sh` —
  [global](global.md). Registering it in both places would just fire it twice.
- **Reason**: **determinism, not token economy**. An instruction competes for
  attention and loses it on a long task; a hook fires every time. The date bump
  fixes something prose cannot: the agent does not reliably know today's date,
  `date +%F` does.
- **Cost**: a hook is free until it *prints*. Definitions never enter the
  model's context — only `additionalContext` and a deny `reason` do. Both new
  hooks are silent on the happy path, so they cost 0 tokens.
  `wiki-reminder.sh` is the opposite: ~70–80 tokens per firing (its message is
  Cyrillic, which tokenizes ~2× worse than Latin), so ~7 config edits in a
  session already cost more than the whole UPDATE/INGEST/LINT block it points
  at.
- **Rejected**: **moving the wiki ruleset wholesale into hooks**. Codex and
  opencode don't execute Claude Code hooks, so those rules would silently
  vanish for them while `AGENTS.md` keeps promising them — against this repo's
  own one-source rule ([cli-agents](cli-agents.md)). Prose also carries the
  *why*, which a one-line reminder cannot.
- ⚠️ **Gotcha**: a commit guard must anchor on the **command segment** (start,
  or after `&&`/`;`/`|`), not on a substring — the first version blocked its own
  test case, because the test merely *contained* the words `git commit`. It also
  requires the colon in `Co-Authored-By:`; without it, the commit documenting
  this very rule would block itself.

### `component: subject` commits, driven by a `/commit` skill (2026-08-08)
- **Decision**: commit messages are `component: subject`, where the component is
  the first path segment of the change. Enforced by the `/commit` skill
  ([global](global.md)), which splits the tree one commit per component and runs
  on `model: haiku` in the current session — no subagent.
- **Reason**: the history had drifted into three styles at once (`feat(nvim):`,
  `darkman: fix …`, bare `formatted`). Of the candidates, this is the one whose
  prefix is **derived, not judged**: the component falls out of `git status`
  mechanically, so it comes out identical every time. The `wiki:` prefix that
  [AGENTS.md](../AGENTS.md) already mandates becomes a special case of the
  general rule rather than an exception to a different one.
- **Rejected**: **Conventional Commits** — its tooling payoff (changelog
  generation, semver) is nil here, and it adds a judgment call (`feat` or
  `chore`? for a keybind tweak) at exactly the point where consistency was the
  goal; it also can't express `wiki:` without contorting into `docs(wiki):`.
- **Rejected**: **a Haiku subagent** (`.claude/agents/committer.md`), the first
  implementation. A subagent starts cold: it reads the diff but cannot know
  **why** a change was made, and the why is what this wiki exists for. The
  `model:` key in a skill's frontmatter gets the cheap model without that cost —
  it is a turn-scoped model switch, and only `context: fork` actually forks a
  subagent. Cheap *and* in-context, so the trade-off that motivated the subagent
  was never real.
- **Rejected**: `effort: low` on Sonnet, briefly in place while the above was
  misunderstood. From the Claude Code model registry: Haiku 4.5 is ~3.75× cheaper
  per token than Sonnet, while `effort: low` buys ~2× (cost index `low 0.47` vs
  `high 1`) and only on thinking tokens. Moot for Haiku regardless — its registry
  entry lists no `effort` capability, so the key would be dead config.
- **Trade-off**: grouping by component means two unrelated edits to the same file
  land in one commit. Acceptable at this repo's size; the fix is to run `/commit`
  more often, not to make the splitting smarter.

### Removal of the yazi autosession plugin (2026-07-18)
- **Decision**: drop `barbanevosa/autosession` from yazi entirely — `package.toml`
  dep, `plugins/autosession.yazi/`, the `init.lua` `:setup()` call, and the `q`
  → `save-and-quit` binding in `keymap.toml`.
- **Reason**: its upstream GitHub repo is gone (404 on `barbanevosa/autosession`),
  so `ya pkg` can no longer fetch/verify it — it was already a dead dependency,
  just not yet cleaned out of the configs that referenced it.
- **Rejected**: waiting for the repo to come back / pinning the last-known
  rev+hash and vendoring it locally — not worth carrying a fork for a small
  session-restore convenience with no upstream maintenance.
- Same pass also fixed unrelated yazi v26.5.6 config breakage (`$schema` key →
  `#:schema` comment, `title_format` → `ind-app-title` DDS event, `[tasks]`
  worker fields, fetcher `id` → `group`) — see [yazi](yazi.md).

### Firefox → Helium as the default browser (2026-07-09)
- **Decision**: use Helium as the default browser in Hyprland, kanata, zsh, and
  the fzf picker scripts. Browser-specific script behavior is centralized in
  `scripts/lib.sh` (`helium-browser`, class `helium`, profile
  `~/.config/net.imput.helium/Default`) instead of scattered as raw Firefox
  strings.
- **Reason**: the migration crosses several contracts at once: Hyprland window
  class, new-window launching, bookmarks export, brotab tab activation, and
  `yt-dlp` cookies. A shared browser helper keeps bookmarks/search/youtube
  aligned and makes future browser changes smaller.
- **Rejected**: blind `firefox` → `helium-browser` replacement. That would leave
  Firefox `places.sqlite` export, Firefox-only brotab clients, and
  `yt-dlp --cookies-from-browser firefox` behind.
- Trade-off: `yt-dlp` does not know a `helium` browser name, so the YouTube
  picker uses the Chromium cookie extractor pointed at Helium's profile. See
  [scripts](scripts.md), [hypr](hypr.md), [keymap](keymap.md).

### tmux → kitty native sessions (2026-06)
- **Decision**: remove tmux; do multiplexing and splits with native kitty
  (windows/tabs/layouts). Navigation hotkeys are sent by kanata as `C-S-*`.
- **Reason**: tmux duplicated terminal functionality — its own prefix (`C-s`), its
  own rendering, an extra layer over kitty's GPU rendering. Native kitty gives
  splits and scrollback with no intervening layer; `<M-t>` in nvim and Alt-t in
  [zsh](zsh.md) mirror the old tmux zoom via `kitten @`.
- **Rejected**: staying on tmux (extra layer, theme/navigation desync);
  wezterm's multiplexer (wezterm is also out of use).
- Trade-off: sessions are now tied to kitty; the `~/.config/tmux` config remains
  as a legacy symlink ([bootstrap](bootstrap.md)). See [sessions](sessions.md),
  [kitty](kitty.md).

### kanata as the single keymap engine
- **Decision**: home-row mods, chords, layers, and force-layout — all in kanata,
  rather than spread across hypr `bind`, kitty `map`, zsh `bindkey`.
- **Reason**: kanata operates at the input-device level, so one layout works
  identically across all apps (terminal, browser, IDE). Otherwise the same
  chords would have to be duplicated in every config, risking desync.
  Apps receive ready-made `C-S-*`/`Super` events.
- **Rejected**: separate per-app bindings (hypr/kitty/zsh) — duplication and
  behavior divergence between apps.
- See [kanata](kanata.md), [keymap](keymap.md).

### Removal of Windows/WSL legacy (2026-07-01)
- Removed `autohotkey/`, `glazewm/`, `wezterm/`, `start.bat`; cleaned up glazewm/WSL
  aliases and `winuser`/`explorer.exe`/`powershell.exe` from zshrc; `TERMCMD` → kitty.
- Reason: the machine is now Arch/Hyprland only; the Windows part is no longer needed.
- `awesome/` left as legacy but not yet removed (deliberately).

### Manual symlinks instead of stow/an install script (2026-07-01, superseded 2026-07-04)
- **Decision**: wire up configs manually via symlinks `~/.config/<tool> →
  ~/dotfiles/<tool>` (list — [bootstrap](bootstrap.md)).
- **Reason**: one personal machine, few symlinks created only once —
  an install script/`stow` would be extra infrastructure with no payoff. It's
  transparently visible what links where.
- **Rejected**: `stow` (an extra dependency and directory structure for the same
  result); a generative install script (nothing to automate for a one-off setup).
- **Superseded 2026-07-04**: switched to `bootstrap.sh` — see next entry. The
  "revisit when" trigger (second machine / growing symlink count) was hit.

### Bootstrap script with plain symlinks, not GNU Stow (2026-07-04)
- **Decision**: `bootstrap.sh` at repo root checks for required commands/packages
  (report-only, no auto-install), then `ln -sfvn`s each top-level config dir
  into `~/.config/<name>` (whole-directory symlinks: `hypr`, `kitty`, `nvim`,
  `kanata`, `waybar`, `yazi`, `darkman`, `lazygit`, `sioyek`, `zathura`,
  `systemd`), plus `zsh/zshrc` → `~/.zshrc` and `zsh/zprofile` → `~/.zprofile`.
- **Reason**: automates what was manual, is idempotent (`ln -sfn` re-running is
  a safe no-op), and needs no new dependency.
- **Rejected**: **GNU Stow** — tried first, but stow's model is per-file
  fan-out that expects the package's internal path to mirror the target
  (`pkg/.config/pkg/file` → `~/.config/pkg/file`). This repo's layout is flat
  (`dotfiles/hypr/hyprland.conf` directly), which whole-directory symlinks
  handle natively but stow's per-file placement fights: tested against the
  live `~/.config` (already whole-directory symlinks) and stow either
  unpacked them into real directories with per-file links (a structural
  change with no benefit) or hit outright conflicts (e.g. `nvim/init.lua` vs
  `yazi/init.lua`) that aborted the whole operation. Restructuring the repo to
  fit stow's model was rejected as unnecessary extra churn for a one-machine
  (now few-machine) setup.
  Also rejected: auto-installing missing packages via pacman/yay — more
  invasive and requires sudo; left as a manual step so the user reviews
  what's installed.
- See [bootstrap](bootstrap.md).

### Repo rules in one file: AGENTS.md is a symlink to CLAUDE.md (2026-08-08)
- **Decision**: `CLAUDE.md` holds this repo's agent rules; `AGENTS.md` is a
  symlink to it (relative target, tracked by git). `bootstrap.sh` re-creates it
  only as repair.
- **Reason**: `CLAUDE.md` used to be a note ("the main instructions are in
  AGENTS.md, read it"). Claude Code auto-loads only `CLAUDE.md`, so a session
  began without the wiki rules in context and had to spend a tool call — or
  silently skip them. Observed live: a session on 2026-08-08 learned the wiki
  rules only because the task happened to involve reading the file. A symlink
  makes the direction irrelevant to tools — Claude Code loads `CLAUDE.md`,
  Codex and opencode read `AGENTS.md` by convention, all three resolve to the
  same bytes. Mirrors how global instructions already work (`instructions.md` →
  three per-tool names, see [bootstrap](bootstrap.md)). `CLAUDE.md` was chosen
  as the real file because Claude Code is the tool actually in daily use here —
  and because that is where these instructions originally lived, before
  `2b57e9b` moved them to `AGENTS.md`.
- **Rejected**: **the pointer note** (either direction) — the rules reach
  context only when the agent chooses to follow it. **Duplicating** the content
  into both files — guarantees drift. The mirror-image symlink (`CLAUDE.md` →
  `AGENTS.md`) was briefly in place and is functionally identical; the only
  difference is which filename carries the git history.
- **Cost**: the file is now resident in every Claude session (~4.5 KB, ~1.1k
  est. tokens). Keep additions to `CLAUDE.md` tight.
- See [bootstrap](bootstrap.md).
