---
title: scripts-pickers
type: component
updated: 2026-08-14
covers:
  - scripts/lib.sh
  - scripts/apps.sh
  - scripts/bookmarks.sh
  - scripts/search.sh
  - scripts/youtube.sh
  - scripts/youtube-qat.sh
---

# scripts — fzf pickers (QAT panels)

Parent: [scripts](scripts.md). The panel mechanism these share is also reused by
the session pickers ([sessions](sessions.md)) and the scratch note
([scripts-scratch](scripts-scratch.md)).

## fzf pickers (shared `lib.sh`)

All the pickers (`apps.sh`, `bookmarks.sh`, `search.sh`, `youtube.sh`) are fzf
loops living inside a **long-lived** kitty quick-access panel (QAT). Their
shared engine is `lib.sh`, which is **sourced, not executed**: it doesn't run as
a standalone program but is pulled in via `source lib.sh`, and therefore has to
be safe under `set -euo pipefail`.

(Separately, the session pickers in [`kitty/scripts/`](../kitty/scripts/) —
`kitty-zoxide-session.sh`, `kitty-list-sessions.sh` — reuse the same QAT launch
via `lib.sh`, but are **one-shot** panels: they act then close instead of
looping. See [sessions](sessions.md).)

**Why the panel is long-lived instead of launched on every hotkey.** The panel
is single-instance (`--instance-group`), so sending the same kitty launch
command again doesn't spawn a second terminal but **toggles the visibility** of
the one already running (`toggle_qat`). The picker process stays alive between
shows (`run_picker` is an endless `while`), so opening is instant — fzf doesn't
cold-start again. Esc in fzf is treated as "hide and re-arm," not "quit."

Key parts of `lib.sh`:

- `run_qat_panel` / `toggle_qat` — show/hide the panel via the remote-control
  socket of the **main** kitty (`main_kitty_socket` filters `/tmp/kitty-*` by
  process name so it doesn't accidentally target some other floating terminal).
  `run_qat_panel` centralizes the launch (with a 3× retry — the socket file
  existing doesn't guarantee the listener is ready on a cold start) and
  `toggle_qat` is just it with a soft failure.
- `launch_qat` — `switch_to_english` + show the panel, and **start a main kitty
  when none is running only if the picker asked for it** via `qat_need_kitty=1`.
  Only the session pickers set it; every other picker (apps, bookmarks, youtube,
  search) must never create a kitty (its host must already exist), so without a
  running main kitty they silently no-op instead of spawning one.

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
