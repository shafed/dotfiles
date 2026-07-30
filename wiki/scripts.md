---
title: scripts
type: component
updated: 2026-07-30
covers:
  - scripts/
---

# scripts

🚧 The most active and complex part of the repo. Three blocks: fzf pickers,
training logbook, misc.

## fzf pickers (shared `lib.sh`)

All the pickers (`apps.sh`, `bookmarks.sh`, `search.sh`, `youtube.sh`) are fzf
loops living inside a **long-lived** kitty quick-access panel (QAT). Their
shared engine is `lib.sh`, which is **sourced, not executed**: it doesn't run as
a standalone program but is pulled in via `source lib.sh`, and therefore has to
be safe under `set -euo pipefail`.

**Why the panel is long-lived instead of launched on every hotkey.** The panel
is single-instance (`--instance-group`), so sending the same kitty launch
command again doesn't spawn a second terminal but **toggles the visibility** of
the one already running (`toggle_qat`). The picker process stays alive between
shows (`run_picker` is an endless `while`), so opening is instant — fzf doesn't
cold-start again. Esc in fzf is treated as "hide and re-arm," not "quit."

Key parts of `lib.sh`:

- `launch_qat` / `toggle_qat` — show/hide the panel via the remote-control
  socket of the **main** kitty (`main_kitty_socket` filters `/tmp/kitty-*` by
  process name so it doesn't accidentally target some other floating terminal).

⚠️ Gotcha (`main_kitty_socket` must exclude QAT panels themselves): every QAT
panel (apps/bookmarks/youtube) is *also* a `kitty` process (`kitty +kitten
panel --instance-group=...`), so a naive "argv starts with the kitty binary"
match is true for panels too, not just the real main terminal. The function
used to return the first `/tmp/kitty-*` socket matching that prefix, in
lexicographic order — which happens to be the real main kitty only if it was
started before the panels got their PIDs. On a machine where a panel's PID
sorts before the main kitty's, `toggle_qat`/`launch_qat` end up sending
remote-control actions to a panel's own kitty process instead of the main one,
which fights with that panel's own event loop/fzf for input — symptom:
apps.sh's picker intermittently stops accepting keystrokes (only Ctrl-C, i.e.
SIGINT via the tty, still works). Fixed by explicitly skipping any socket
whose process argv contains `+kitten panel`.
- `switch_to_english` — forces the `us` layout (index 0 in `us,ru`) via
  `hyprctl switchxkblayout`, so fzf queries get typed in Latin script even when
  Russian is active. Called inside `launch_qat` on **every** show, because on
  toggle the picker's own `switch_to_english` (which only runs on cold-start)
  doesn't fire.
- `FZF_DEFAULT_OPTS` is hardcoded for gruvbox: QAT runs under bash and doesn't
  inherit the interactive zsh fzf config.
- Browser helpers (`browser_window_off_workspace`, `open_in_new_browser_window`,
  `move_browser_when_up`, `open_or_focus_url`) — shared Helium/Hyprland logic
  for delivering tabs away from the YouTube workspace. The browser contract is
  centralized in `lib.sh`: `helium-browser`, Hyprland class `helium`, desktop id
  `helium.desktop`, profile `~/.config/net.imput.helium/Default`.

⚠️ Gotcha: all external process launches go with `</dev/null` and `disown`. QAT
keeps the panel open as long as some process holds its tty
(`close_on_child_death=no`), and a browser tied to that tty would get killed on
a force-close of the panel.

⚠️ Gotcha (browser cold-start): on a true cold start the window takes several
seconds to appear (process + profile + first frame), so `move_browser_when_up`
polls for ~12s — otherwise the tab would open on the wrong workspace.

### apps.sh — launching applications

Fuzzy search over `.desktop` entries from XDG dirs, launches the selected one.
Enter **focuses an already-open window** of the app (matched by WM class via
`hyprctl`), Alt+Enter always spawns a new instance (Shift+Enter isn't available
in fzf — the terminal doesn't send a distinct code).

Design decisions:

- The `~/.cache/apps-fzf/apps.tsv` cache is rebuilt only when the app dir's
  mtime has changed (a `.desktop` added/removed) — cheap, and catches new
  applications without a manual `-r`.
- The usage tally is stored **separately** from the catalog so that "sorted by
  launch frequency" order survives a rebuild. An empty query shows
  "recent/most-used," typing switches to the full catalog (fzf `change:reload`).
- Launching goes through the parsed `Exec=`, **not** `gtk-launch`:
  `gtk-launch`/`gio launch` silently no-op on `DBusActivatable=true` with a
  D-Bus-invalid id (e.g. Telegram's hashed Flatpak id) and return 0.
- Fuzzy window matching (class normalization, suffix comparison):
  `StartupWMClass` routinely doesn't match the live window class (the Telegram
  case). `Telegram` is excluded from the empty-query recent list so it doesn't
  clutter it.

### bookmarks.sh — bookmarks (focus an existing browser tab)

Fuzzy search over bookmarks, opens in Helium **preferring an already-open tab**
via **brotab** (`bt list` → `bt activate --focused`) rather than duplicating it.

⚠️ Gotcha (brotab): `bt` is an optional dependency (pipx), requires the brotab
extension and native-messaging manifest to be installed for Helium. Without it
— fallback to launching the URL with `helium-browser`.
`bt activate --focused` on Hyprland doesn't raise the window itself, so the
window is raised manually — `focus_browser_for_title` finds the window by tab
title (the tab title becomes the window title after activation), so that the tab
on the YouTube ws wins, not some random other browser window. `lib.sh` filters
brotab prefixes to Helium/Chromium-like clients so a leftover Firefox brotab
client cannot steal a migrated open.

- Sources: its own `bookmarks.tsv`, the private dotfiles-private, and an
  auto-export of Helium bookmarks (`export_browser_bookmarks`) from
  `~/.config/net.imput.helium/Default/Bookmarks`. This is Chromium JSON, not
  Firefox `places.sqlite`, so `jq` is used and duplicate URLs are dropped.
- New tabs are **never** opened on the YouTube workspace (ws4):
  `prepare_browser_for_new_tab` picks a `tab`/`newwindow`/`cold` strategy.
- Recents log same as in apps.sh: empty query → recently opened.

### search.sh — web search (split out of bookmarks.sh)

**Why it's separate from bookmarks.sh** (commit "split web search into
search.sh"): the "search the web" address-bar-like half was carved out into its
own independent QAT with no bookmark rows — bookmarks.sh now only searches
bookmarks. You type a query → live Google suggestions
(`suggestqueries.google.com`) → Enter on a suggestion or on your raw query opens
the search in Helium (same brotab logic as bookmarks.sh). The Google suggestions
URL still uses `client=firefox`; that is only Google's response format selector,
not a local Firefox dependency.

⚠️ Gotcha (debounce): `suggest_rows` does a **leading** `sleep 0.18` before the
curl. fzf kills the previous reload process on every keystroke, so the pause
means the request only goes out to the network on a pause in typing — not once
per character. fzf runs in `--disabled` mode (we build the list ourselves) +
`--print-query` (Enter on the raw query).

### youtube.sh / youtube-qat.sh

`youtube.sh` — a yt-dlp video picker by channel/playlist/search; the preview is
a thumbnail (kitty graphics, falls back to chafa) + title. `youtube-qat.sh` — a
thin wrapper that launches `youtube.sh -s` as a kitty panel (bound to the kanata
apps layer).

- Videos open on **ws4** (unlike bookmarks/search, which use ws2).
- `-H`/`-L` (history/watch-later) read the logged-in session via
  `--cookies-from-browser chromium:~/.config/net.imput.helium/Default` (no
  OAuth). `yt-dlp` does not support `helium` as a browser name, so the
  Chromium extractor is pointed at Helium's profile path.
- `-s` live search: Enter on an empty query opens the page matching the active
  mode — Watch Later for Videos, `youtube.com/feed/channels` for Channels,
  History for History, and the WL playlist in Watch Later mode. This keeps the
  picker useful as a quick route to the corresponding full YouTube view when no
  item is selected.
  Otherwise, Enter with no results opens the corresponding full YouTube view
  with the typed query: regular results for Videos or channel-filtered results
  for Channels (an `enter:transform` bind checks `{}` for emptiness). History
  and Watch Later have no reliable URL-addressable video filter, so filtering
  those feeds remains local to the picker; their no-result fallbacks open the
  corresponding unfiltered feed pages.
  ⚠️ Gotcha: the fallback sentinel must stay a plain two-field row, not the
  usual 6-column shape — `IFS=$'\t' read` collapses *consecutive* tab delimiters
  (tab is IFS-whitespace), so extra empty columns would swallow the payload into
  nothing.

⚠️ Gotcha (cache/preview): the preview makes **no** network requests on hover —
everything comes from the already-built TSV; the thumbnail is downloaded once
and cached in `~/.cache/youtube-fzf/thumbs`. Fallback order is
`hqdefault→mqdefault→default` (hqdefault always exists). The preview function
runs as a subprocess (the `--preview` branch) and doesn't depend on the rest of
the script.

### nvim-scratch-toggle.sh / nvim-scratch-run.sh / nvim-scratch-quit.sh — scratch note that pastes itself

`SUPER, N` (hypr/hyprland.conf) toggles a floating kitty+nvim scratchpad for
jotting a quick note and pasting it into whatever text box was focused before
the scratchpad opened — no manual copy/paste. Reuses the QAT mechanism above
(`launch_qat`/`lib.sh`) rather than a Hyprland special workspace, so it gets
the same "re-press to toggle visibility, process survives a hide" behavior as
apps.sh/bookmarks.sh for free, in its own `scratch` instance-group.

- `nvim-scratch-toggle.sh`: records the currently-focused window's Hyprland
  address (`hyprctl activewindow`) to `~/.cache/nvim-scratch-target` — this
  is what quit will paste back into — then calls `launch_qat "scratch"` with
  `/usr/bin/env bash nvim-scratch-run.sh <scratch_file> <quit_script>` (fixed
  scratch-file path, so content survives a hide/reshow cycle). The address
  capture happens unconditionally on every press: harmless when the press is
  about to *hide* the panel (nothing reads it until nvim actually quits,
  which can't happen while hidden), correct when the press is about to
  *show* it.
- `nvim-scratch-run.sh`: `nvim +startinsert
  "+autocmd VimLeavePre * silent! write" -- "$1"` (drop straight into
  insert mode — this is a "jot something down" scratchpad, not editing)
  then `exec "$2"` (the quit script). The VimLeavePre autosave is
  load-bearing: the user's fast-quit maps (`<M-q>`/`<M-Esc>`, all modes
  including insert — `nvim/lua/config/keymaps.lua`) run `:q!`, which
  discards the buffer, and the quit hook would then find an empty scratch
  file and paste nothing. For this scratchpad every exit means "I'm done,
  paste it".
- `nvim-scratch-quit.sh`: runs once nvim exits (inherits its PID via `exec`
  in run.sh). `wl-copy`s the scratch file — through `printf '%s'
  "$(<file)"`, which strips all trailing newlines (nvim always writes a
  final one; it would land as an extra Enter in the target text box) —
  clears it for next time, then
  spawns a paste helper via **`systemd-run --user`** and kills the panel;
  the helper waits for the panel process to die, `hyprctl dispatch
  focuswindow`s back to the recorded address, and simulates a paste via
  wtype — no ydotool/ydotoold on this machine, and wtype needs no daemon on
  wlroots compositors. The chord depends on the target's Hyprland class:
  plain `ctrl+v` everywhere except a `kitty` target, which gets
  `ctrl+shift+v` (kitty's own `kitty_mod+v` paste binding — plain ctrl+v
  isn't bound to anything in a terminal).

⚠️ Gotcha (paste MUST happen after the panel dies, from a process outside
the panel's cgroup) — two layers, both hit in sequence:

1. The panel is a layer-shell overlay with `--focus-policy=exclusive` —
   while it is alive it swallows ALL keyboard input, **including wtype's
   synthetic keys**. The first cut focused the target and pasted before
   killing the panel (via an EXIT trap): the log showed `focuswindow`
   dispatched and wtype exiting 0, yet nothing arrived — the chord went
   into the still-open panel. Diagnosed by elimination with a disposable
   `kitty --class wtype-probe -e sh` target plus `kitty @ get-text` to
   inspect the pty directly: the identical wtype chord pastes fine when no
   panel is involved. And the kill can't simply be moved earlier in the
   same script: the panel closing HUPs its pty, which would take the script
   down with it mid-paste — the paste has to come from a detached helper
   that outlives the panel.
2. A `setsid`-detached helper is NOT detached enough: kitty spawns the
   panel's children inside a transient systemd scope (`kitty-<pid>-N.scope`
   — visible in the journal as "Started kitty child process ..."), and when
   the panel dies systemd tears down the whole scope **cgroup**. `setsid`
   changes the session (immune to the pty HUP) but not the cgroup, so the
   helper was reaped before writing a single log line. `systemd-run --user
   --collect` puts the helper in its own scope outside the doomed cgroup
   (with `WAYLAND_DISPLAY`/`HYPRLAND_INSTANCE_SIGNATURE` passed through via
   `--setenv`, since the transient unit doesn't inherit the caller's env
   beyond what the user manager already has). The helper then polls
   `kill -0` until the panel PID is gone, polls `hyprctl activewindow`
   until the target address is actually focused, and only then types the
   chord.

⚠️ Gotcha (why run.sh is a real file, not an inline string): the first cut
passed `/usr/bin/env bash -c "nvim -- '$scratch_file'; exec '$quit_script'"`
straight to `launch_qat`. That string has to survive being re-serialized
across the remote-control call into the already-running main kitty and the
quick-access-terminal kitten's own re-exec of `+kitten panel` before it
becomes argv for the panel's child process — it did not survive intact: nvim
came up with zero arguments (landing on its startup dashboard instead of the
scratch file), consistent with the semicolon-joined, quote-embedded string
being re-tokenized somewhere along that chain rather than passed through
as one opaque token. A plain script path plus two plain argv tokens (no
shell metacharacters left to mangle) fixed it — same shape as apps.sh's
`bash "$script_path" "${pick_args[@]}"`, which never hit this because it
never embeds `;`/quotes in what it hands to `launch_qat`.

⚠️ Gotcha (this is why quit_script kills its own parent): kitty.conf leaves
`close_on_child_death` at its default (`no`, see the QAT gotcha above) — the
panel does NOT disappear on its own once the wrapped command exits, it would
sit there showing a dead pane. Since `nvim-scratch-quit.sh` is `exec`'d in
place of run.sh, `$PPID` inside it is the panel's own kitty process; quit.sh
kills that PID explicitly on every exit path so the panel actually closes
instead of lingering.

## Training logbook

## Downloads clipboard watcher

`watch-downloads.sh` is run by the user systemd unit
`systemd/user/watch-downloads.service`. It watches `~/Downloads` with
`inotifywait` and copies each completed download to the clipboard:

- image files (`png`, `jpg`, `webp`, etc.) are copied as `image/*` via CopyQ,
  with `text/plain` and `text/uri-list` alongside it, so browsers/Claude paste
  the bitmap instead of literal `file://...` text;
- non-image files are copied as `text/uri-list`, which `mini.files` can paste
  into the current directory with `<leader>p`.

The unit intentionally starts the script from `~/dotfiles/scripts/` rather than
`~/.local/bin`, so the behavior is versioned with the rest of the dotfiles.

### generate_logbook.py

Generates a **single self-contained** `logbook.html` from the markdown sessions
in `~/obsidian/training/`. CSS+JS are inlined into the HTML, exercise
data is injected as JSON (`__EXDATA__`). Structure: parse sessions/events →
minimal markdown→HTML → render → assemble the page (`main`).

Key decisions (from git evolution):

- **Mood via session YAML frontmatter** (`mood: bad|mid|great`), not an inline
  tag in the body — commit "Add session-level mood via YAML frontmatter." Mood
  is a property of the whole session, so it lives in the file header; parsed by
  `MOOD_FM_RE`.
- **Search evolution**: fuzzy (`f49a39f`) → ranked (`832326c`, weighted
  `searchScore`: exact date match 10000, substring 8000, tokens 150/25/5) →
  speed up (`f9594b3`) → debounce (`48314a5`). ⚠️ Gotcha: `input` is debounced
  at **220ms** (`scheduleSearch`), and match highlighting (`highlight`, an
  expensive TreeWalker) is deferred and capped at the top 50 results
  (`scheduleHighlight`) — otherwise typing lags on a large feed.
- **Split dates in search** (`c26e2dc`): `2026 06` matches `2026-06-*`.
- **Exercise history** (`ce289e2`): clicking an exercise name → its history; the
  exercise list is sorted by last use, not alphabetically (`0a0133a`).
- **note-links / nvim-edit** (`fc30a5c`): in the feed and history — links
  `nvim-edit://<percent-encoded absolute path>` that open the session's source
  md file. Handled by `nvim-edit-handler.sh` (see below).

### nvim-edit-handler.sh — the `nvim-edit://` handler

Handles `nvim-edit://` links from the logbook (see [nvim](nvim.md),
[sessions](sessions.md)). Opens the file in the kitty **obsidian** session as a
new nvim tab.

Design (a two-level fallback, because the kitty session and nvim are
asynchronous):

1. Via `kitty-zoxide-session.sh --named obsidian`, focuses/creates the obsidian
   session in the **main** (non-floating) kitty — not in transient panels like
   apps.sh.
2. Prefers `nvim --remote-tab` over the nvim socket
   (`$XDG_RUNTIME_DIR/nvim.<pid>.0`, the pid is searched with a ±5 delta since
   the exact nvim pid is unstable); on failure falls back to `kitty send-text`
   (`:tabedit` into a running nvim, or `nvim <file>` in a bare shell).

### Connections

- `nvim-edit-handler.sh` ↔ the kitty obsidian session and its nvim (see
  [sessions](sessions.md)).
- `generate_logbook.py` (generates links) ↔ `nvim-edit-handler.sh` (opens them).

## Misc

### sudo-notify.sh — sudo password-prompt notifier

`~/.local/bin/sudo` is a thin wrapper (`exec ".../scripts/sudo-notify.sh" "$@"`,
same shape as `nvim-edit-handler`) that shadows `/usr/bin/sudo` earlier in
`$PATH` (`zsh/zshrc` puts `~/.local/bin` first). The real logic lives here so
it's versioned with the rest of the dotfiles instead of only existing as an
unversioned file in `~/.local/bin`. `bootstrap.sh` writes this wrapper (see
`link_configs`'s "Installing ~/.local/bin wrappers" step), so a fresh
`git clone` + `./bootstrap.sh` gets the notification working with no manual
step.

Sends a `notify-send` if a sudo call is about to block on a password **and**
the terminal window it's running in isn't currently focused (Hyprland-only,
via `hyprctl activewindow`) — otherwise a password prompt sitting in a
background terminal goes unnoticed. Design:

- First does `sudo -n true` (non-interactive credential check): if a valid
  sudo timestamp already exists, no prompt will occur, so it skips the
  notification path entirely.
- Otherwise walks up the process tree from its own PID (capped at 12 hops) to
  find the enclosing terminal emulator (`TERMINAL_COMMS` — kitty, alacritty,
  foot, etc.), and compares that PID against Hyprland's active window PID.
- Always `exec`s the real `/usr/bin/sudo` at the end regardless of the notify
  path, so behavior/exit code/stdio are byte-identical to calling sudo
  directly — this wrapper is meant to be fully transparent.

### obsidian-sync.sh

Shared git sync for `~/obsidian`, single source of truth for pull-on-entry and
push-on-exit so call sites stop inlining their own `git pull`/`git push`.
`{pull|push} [silent]`:

- `pull` — `git pull --rebase --autostash`, throttled to once per 30s via a
  `~/.cache/obsidian-sync/last-pull` marker (multiple kitty sessions opened back
  to back, e.g. todos → obsidian, would otherwise repull within seconds).
- `push` — `git add -A`, commit as `Vault backup: <timestamp>` if there's
  anything staged, then `git push`; `silent` suppresses the success message.

Call sites: [`../kitty/sessions/obsidian.kitty-session`](../kitty/sessions/obsidian.kitty-session)
and `daily-notes.sh` (pull side, see below and [sessions](sessions.md)),
[`../nvim/lua/utils/obsidian.lua`](../nvim/lua/utils/obsidian.lua) (push side —
`push_with_cooldown` fire-and-forget for frequent events, `push_sync` blocking
for events where nvim is about to exit, so a mid-cooldown push doesn't eat the
one that actually mattered).

### daily-notes.sh

Opens today's daily note in nvim inside a **per-day kitty session**
(`daily-<note>.kitty-session`), creating the note on first access. Layout:
`~/obsidian/journal/<YYYY-MM-DD-Weekday>.md` — the folder is flat, so the path
must stay in sync with `daily_notes_folder` in the vault's `.moxide.toml`.

On first entry it does `obsidian-sync.sh pull`, then opens straight into the
note (`nvim "+norm G" <full_path>`) — deliberately **no** `persistence.load()`.
Earlier versions tried combining the two for a "reopen last layout"
convenience, but the journal directory is shared by every daily note, so
persistence could restore an older multi-tab layout instead of showing today's
note. See [sessions](sessions.md) for the history.

### symlayout-watch.sh

Forces the `us` layout while kanata's symbol layers are active. Called
**directly by kanata actions** (`enter`/`leave`/`app`), with no TCP server. See
[kanata](kanata.md).

- A POSIX-sh port of the old Python version — about 13ms faster per call (no
  interpreter startup), which matters since it's invoked on every layer
  entry/exit.
- `enter` remembers the current layout index in a state file and switches to
  `us`; `leave` restores the saved index. The state file also guards against a
  double enter.
