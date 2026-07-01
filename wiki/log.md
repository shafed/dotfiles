# Wiki log

Append-only log of wiki operations. Newest at the bottom. Prefixes for parsing:
`INIT` · `INGEST` · `UPDATE` · `LINT` · `DECISION`.

- 2026-07-01 INIT — created wiki skeleton: index, CONVENTIONS, log, component
  (kanata, scripts, hypr, kitty, nvim, zsh, waybar, yazi) and cross-cutting (keymap,
  sessions, theming, decisions, bootstrap) stub pages. Added root
  CLAUDE.md with ingest/update/lint rules.
- 2026-07-01 DECISION — removed Windows/WSL legacy (autohotkey, glazewm, wezterm,
  start.bat; glazewm/WSL aliases and winuser in zshrc; TERMCMD→kitty). See decisions.md.
- 2026-07-01 UPDATE — filled in kanata.md, keymap.md, sessions.md (keymap domain): opposite-hand HRM (-release, neutral/timeout hold), chord timings 35/80 and the rolls-vs-mod-combos trade-off, symbol US-xkb-wrap, kitty-send replacing the tmux prefix, apps force-English, numplain2; the cross-cutting boundary kanata↔hypr(Super)↔kitty(C-S-) + conflict table; tmux→kitty sessions migration, nvim-edit-handler/obsidian, recorded that daily-notes.sh is already native-kitty (tmux only in a stale comment).
- 2026-07-01 UPDATE — filled in scripts.md (scripts domain): fzf pickers (long-lived QAT toggle, brotab tab-focus, ws routing around the YouTube ws, leading-debounce for suggestions), training logbook (mood via YAML frontmatter, search evolution fuzzy→ranked→debounce, nvim-edit-links, xlsx cell-colors→mood) and the rest (daily-notes native-kitty, symlayout-watch↔kanata).
- 2026-07-01 UPDATE — filled in hypr.md, kitty.md, waybar.md, yazi.md, theming.md (desktop domain): hypr minimalism + lazy browser launch, kitty.conf ~3000 lines = a dump of defaults (given a grep for the real ~40), pass_keys/get_layout, waybar modules (mediaplayer/power outside the repo), yazi plugins (clipboard empty), the theme is static — gruvbox dark duplicated by hand, darkman scaffolding empty, hyprsunset gamma only.
- 2026-07-01 UPDATE — filled in zsh.md, nvim.md, bootstrap.md, decisions.md (shell/editor domain): oh-my-zsh + built-in plugin bootstrap, LazyVim + logbook integration, symlink table, decisions with trade-offs (tmux→kitty, kanata engine, symlinks-vs-stow). Cleanup findings: dead im-select.exe (/mnt/c/...), sync-vi/sv pointing at a non-existent path, legacy tmux/wezterm symlinks, two secrets in git (OPENROUTER_API_KEY, TODOIST_API_TOKEN).
- 2026-07-01 LINT — coordinator: all internal links resolve, no stubs remain; index updated (🌱→🚧, status, legend) and the theming line fixed (no dynamic light/dark).
- 2026-07-01 UPDATE — cleanup: removed secrets and dead lines in zshrc (im-select/mnt-c, sync-vi/sv, duplicate PATH), removed legacy symlinks ~/.config/{tmux,wezterm}.
- 2026-07-01 UPDATE — all internal wiki links converted to [[wikilinks]] (except the external ../CLAUDE.md).
- 2026-07-01 DECISION — moved the main agent instructions into AGENTS.md (a cross-agent standard, also read by Codex); CLAUDE.md reduced to a pointer to it plus Claude specifics.
- 2026-07-01 UPDATE — translated the whole wiki (all pages, CONVENTIONS, this log) plus AGENTS.md and CLAUDE.md from Russian to English, for a single language across the agent-facing knowledge layer. Structure, frontmatter, [[wikilinks]], covers: paths, statuses and commit hashes preserved.
