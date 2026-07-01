---
title: scripts
type: component
updated: 2026-07-01
covers:
  - scripts/
---

# scripts

🚧 The most active and complex part of the repo. Three blocks: fzf pickers, training logbook,
misc.

## fzf pickers (shared `lib.sh`)

All the pickers (`apps.sh`, `bookmarks.sh`, `search.sh`, `youtube.sh`) are
fzf loops living inside a **long-lived** kitty quick-access panel (QAT). Their
shared engine is `lib.sh`, which is **sourced, not executed**: it doesn't run
as a standalone program but is pulled in via `source lib.sh`, and therefore has to be
safe under `set -euo pipefail`.

**Why the panel is long-lived instead of launched on every hotkey.** The panel is
single-instance (`--instance-group`), so sending the same kitty launch
command again doesn't spawn a second terminal but **toggles the visibility** of the
one already running (`toggle_qat`). The picker process stays alive between shows
(`run_picker` is an endless `while`), so opening is instant — fzf doesn't
cold-start again. Esc in fzf is treated as "hide and re-arm," not
"quit."

Key parts of `lib.sh`:
- `launch_qat` / `toggle_qat` — show/hide the panel via the remote-control socket
  of the **main** kitty (`main_kitty_socket` filters `/tmp/kitty-*` by process
  name so it doesn't accidentally target some other floating terminal).
- `switch_to_english` — forces the `us` layout (index 0 in `us,ru`) via
  `hyprctl switchxkblayout`, so fzf queries get typed in Latin script even when
  Russian is active. Called inside `launch_qat` on **every** show, because on
  toggle the picker's own `switch_to_english` (which only runs on cold-start) doesn't
  fire.
- `FZF_DEFAULT_OPTS` is hardcoded for gruvbox: QAT runs under bash and doesn't inherit
  the interactive zsh fzf config.
- Firefox helpers (`firefox_window_off_workspace`, `open_in_new_firefox_window`,
  `move_firefox_when_up`) — shared logic for delivering tabs away from the YouTube workspace.

⚠️ Gotcha: all external process launches go with `</dev/null` and `disown`. QAT
keeps the panel open as long as some process holds its tty
(`close_on_child_death=no`), and Firefox, tied to that tty, would get killed on a
force-close of the panel.

⚠️ Gotcha (Firefox cold-start): on a true cold start the window takes several
seconds to appear (process + profile + first frame), so `move_firefox_when_up`
polls for ~12s — otherwise the tab would open on the wrong workspace.

### apps.sh — launching applications

Fuzzy search over `.desktop` entries from XDG dirs, launches the selected one. Enter
**focuses an already-open window** of the app (matched by WM class via `hyprctl`),
Alt+Enter always spawns a new instance (Shift+Enter isn't available in fzf — the terminal doesn't send
a distinct code).

Design decisions:
- The `~/.cache/apps-fzf/apps.tsv` cache is rebuilt only when the app dir's mtime has
  changed (a `.desktop` added/removed) — cheap, and catches new applications without
  a manual `-r`.
- The usage tally is stored **separately** from the catalog so that "sorted by launch
  frequency" order survives a rebuild. An empty query shows "recent/most-used,"
  typing switches to the full catalog (fzf `change:reload`).
- Launching goes through the parsed `Exec=`, **not** `gtk-launch`: `gtk-launch`/`gio
  launch` silently no-op on `DBusActivatable=true` with a D-Bus-invalid id
  (e.g. Telegram's hashed Flatpak id) and return 0.
- Fuzzy window matching (class normalization, suffix comparison): `StartupWMClass`
  routinely doesn't match the live window class (the Telegram case). `Telegram` is excluded
  from the empty-query recent list so it doesn't clutter it.

### bookmarks.sh — bookmarks (focus an existing FF tab)

Fuzzy search over bookmarks, opens in Firefox **preferring an already-open tab**
via **brotab** (`bt list` → `bt activate --focused`) rather than duplicating it.

⚠️ Gotcha (brotab): `bt` is an optional dependency (pipx), requires the
FF brotab extension to be installed. Without it — fallback to `xdg-open`. `bt activate --focused` on
Hyprland doesn't raise the window itself, so the window is raised manually —
`focus_firefox_for_title` finds the window by tab title (the tab title becomes the
window title after activation), so that the tab on the YouTube ws wins, not some
random other FF window.

- Sources: its own `bookmarks.tsv`, the private dotfiles-private, and an auto-export
  of FF bookmarks (`export_firefox_bookmarks`). `places.sqlite` is locked while FF is
  running, so it's copied to a temp folder (+WAL/SHM) and read from there.
- New tabs are **never** opened on the YouTube workspace (ws4):
  `prepare_firefox_for_new_tab` picks a `tab`/`newwindow`/`cold` strategy.
- Recents log same as in apps.sh: empty query → recently opened.

### search.sh — web search (split out of bookmarks.sh)

**Why it's separate from bookmarks.sh** (commit "split web search into search.sh"):
the "search the web" address-bar-like half was carved out into its own independent QAT
with no bookmark rows — bookmarks.sh now only searches bookmarks. You type a query →
live Google suggestions (`suggestqueries.google.com`) → Enter on a suggestion or on
your raw query opens the search in FF (same brotab logic as bookmarks.sh).

⚠️ Gotcha (debounce): `suggest_rows` does a **leading** `sleep 0.18` before the curl.
fzf kills the previous reload process on every keystroke, so the pause means
the request only goes out to the network on a pause in typing — not once per character.
fzf runs in `--disabled` mode (we build the list ourselves) + `--print-query` (Enter on
the raw query).

### youtube.sh / youtube-qat.sh

`youtube.sh` — a yt-dlp video picker by channel/playlist/search; the preview is a thumbnail
(kitty graphics, falls back to chafa) + title. `youtube-qat.sh` — a thin wrapper
that launches `youtube.sh -s` as a kitty panel (bound to the kanata apps layer).

- Videos open on **ws4** (unlike bookmarks/search, which use ws2).
- `-H`/`-L` (history/watch-later) read the logged-in session via
  `--cookies-from-browser firefox` (no OAuth).

⚠️ Gotcha (cache/preview): the preview makes **no** network requests on hover — everything
comes from the already-built TSV; the thumbnail is downloaded once and cached in
`~/.cache/youtube-fzf/thumbs`. Fallback order is `hqdefault→mqdefault→default`
(hqdefault always exists). The preview function runs as a subprocess (the
`--preview` branch) and doesn't depend on the rest of the script.

## Training logbook

### generate_logbook.py

Generates a **single self-contained** `logbook.html` from the markdown sessions in
`~/obsidian/periodic/training/`. CSS+JS are inlined into the HTML, exercise data is
injected as JSON (`__EXDATA__`). Structure: parse sessions/events → minimal
markdown→HTML → render → assemble the page (`main`).

Key decisions (from git evolution):
- **Mood via session YAML frontmatter** (`mood: bad|mid|great`), not an inline tag
  in the body — commit "Add session-level mood via YAML frontmatter." Mood is a
  property of the whole session, so it lives in the file header; parsed by `MOOD_FM_RE`.
- **Search evolution**: fuzzy (`f49a39f`) → ranked (`832326c`, weighted `searchScore`:
  exact date match 10000, substring 8000, tokens 150/25/5) → speed up
  (`f9594b3`) → debounce (`48314a5`). ⚠️ Gotcha: `input` is debounced at **220ms**
  (`scheduleSearch`), and match highlighting (`highlight`, an expensive TreeWalker)
  is deferred and capped at the top 50 results (`scheduleHighlight`) — otherwise typing
  lags on a large feed.
- **Split dates in search** (`c26e2dc`): `2026 06` matches `2026-06-*`.
- **Exercise history** (`ce289e2`): clicking an exercise name → its history;
  the exercise list is sorted by last use, not alphabetically
  (`0a0133a`).
- **note-links / nvim-edit** (`fc30a5c`): in the feed and history — links
  `nvim-edit://<percent-encoded absolute path>` that open the session's source md file.
  Handled by `nvim-edit-handler.sh` (see below).

### import_training_log_xlsx.py

A one-time import of history from `Training_Log.xlsx` into md sessions. **No dependencies**:
reads the `.xlsx` as zip XML parts (not openpyxl).

⚠️ Gotcha (cell colors → mood): mood is recovered from the **fill color** of the
notes cell. Green is the base color and is NOT tagged (otherwise almost every workout
would get a tag); only orange→`mid` and red→`bad` produce a mood, which is
written into the session frontmatter (closing the loop with `generate_logbook.py`). Only
direct `rgb` fills are resolved; theme/indexed colors are ignored.

### nvim-edit-handler.sh — the `nvim-edit://` handler

Handles `nvim-edit://` links from the logbook (see [nvim](nvim.md),
[sessions](sessions.md)). Opens the file in the kitty **obsidian** session as a new
nvim tab.

Design (a two-level fallback, because the kitty session and nvim are asynchronous):
1. Via `kitty-zoxide-session.sh --named obsidian`, focuses/creates the obsidian session
   in the **main** (non-floating) kitty — not in transient panels like apps.sh.
2. Prefers `nvim --remote-tab` over the nvim socket
   (`$XDG_RUNTIME_DIR/nvim.<pid>.0`, the pid is searched with a ±5 delta since the exact
   nvim pid is unstable); on failure falls back to `kitty send-text` (`:tabedit` into a
   running nvim, or `nvim <file>` in a bare shell).

### Connections

- `nvim-edit-handler.sh` ↔ the kitty obsidian session and its nvim (see [sessions](sessions.md)).
- `generate_logbook.py` (generates links) ↔ `nvim-edit-handler.sh` (opens them)
  ↔ `import_training_log_xlsx.py` (writes mood into frontmatter, which the
  generator reads).

## Misc

### daily-notes.sh

Opens today's daily note in nvim inside a **per-day kitty session**
(`daily-<note>.kitty-session`), creating the note and its `year/month` directory on
first access. Layout: `~/obsidian/periodic/<YYYY>/<MM-Mon>/<...>.md`.

⚠️ Note (stale comment): the shebang and header still mention tmux, but
the script has already migrated to **kitty native sessions** (`kitten @ action
goto_session`); on first entry it does `git -C ~/obsidian pull` and
`persistence.load()` instead of the old tmux "s". See [sessions](sessions.md).

### symlayout-watch.sh

Forces the `us` layout while kanata's symbol layers are active. Called
**directly by kanata actions** (`enter`/`leave`/`app`), with no TCP server. See
[kanata](kanata.md).

- A POSIX-sh port of the old Python version — about 13ms faster per call (no
  interpreter startup), which matters since it's invoked on every layer entry/exit.
- `enter` remembers the current layout index in a state file and switches to `us`;
  `leave` restores the saved index. The state file also guards against a
  double enter.
