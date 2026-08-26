---
title: scripts-pickers
type: component
updated: 2026-08-26
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
panel (apps/bookmarks/youtube) is _also_ a `kitty` process
(`kitty +kitten panel --instance-group=...`), so a naive "argv starts with the
kitty binary" match is true for panels too, not just the real main terminal. The
function used to return the first `/tmp/kitty-*` socket matching that prefix, in
lexicographic order — which happens to be the real main kitty only if it was
started before the panels got their PIDs. On a machine where a panel's PID sorts
before the main kitty's, `toggle_qat`/`launch_qat` end up sending remote-control
actions to a panel's own kitty process instead of the main one, which fights
with that panel's own event loop/fzf for input — symptom: apps.sh's picker
intermittently stops accepting keystrokes (only Ctrl-C, i.e. SIGINT via the tty,
still works). Fixed by explicitly skipping any socket whose process argv
contains `+kitten panel`.

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

⚠️ Gotcha (switch workspace BEFORE spawning, not after): whenever a new browser
window has to be created (`open_in_new_browser_window`'s `newwindow` path, and
the `cold`-start path in `open_or_focus_url` / `youtube.sh`'s `open_url`),
`switch_to_workspace` is called **first**, then the browser is launched.
Hyprland places a new window on the currently active workspace, so launching
before switching made the window flash onto whatever workspace was active —
visible as a broken fullscreen if that happened to be the YouTube workspace
mid-video — before the follow-up move dispatch pulled it away. The move/focus
dispatches after the launch are kept as a belt-and-suspenders fallback, not the
primary placement mechanism anymore.

⚠️ Gotcha (switching to an empty ws2 races `hyprland.lua`'s `on-created-empty`
rule): `hl.workspace_rule({ workspace = "2", on_created_empty = browser })`
auto-launches a bare browser window the moment ws2 is focused while it has zero
windows — exactly the state `switch_to_workspace` produces right before spawning
one of its own. Left unhandled, this races: the rule's bare window and the
script's own (`--new-window` in `open_in_new_browser_window`, or a plain launch
in the `cold` path) both land, so opening a bookmark while the only browser
window was fullscreen elsewhere (ws2 therefore empty) visibly opened **twice**
and took roughly twice as long. Fixed by `switch_to_workspace_for_browser`
(`lib.sh`): it checks whether the target workspace was empty _before_ switching,
and if so, polls briefly for a browser window to land there and hands its
address back via the global `rule_browser_addr`. Callers that see it set reuse
that window (a plain tab open) instead of also forcing their own.
`open_in_new_browser_window` and both `cold`-start call sites use it instead of
the bare `switch_to_workspace`. The rule's own blank tab (`chrome://newtab/`) no
longer lingers alongside the opened URL: `open_browser_url` (`lib.sh`) checks
`empty_browser_tab_id` first and, when an empty tab is open, navigates it in
place via `bruvtab navigate` + `bruvtab activate --focused` instead of opening a
new one — so the rule's blank tab gets filled in rather than sitting next to a
second tab. Matches `chrome://newtab/`, `chrome://new-tab-page/`,
`edge://newtab/`, and `about:blank`; falls back to the old plain-launch behavior
when `bruvtab` is unavailable or no empty tab is found.

⚠️ Gotcha (bruvtab discovery lags the rule's own window): a single
`empty_browser_tab_id` check right after the rule creates its window can still
race — `bruvtab list` needs a moment to index the brand-new window before the
blank tab shows up in it. A check that fires too early finds nothing and falls
through to the plain-launch fallback, which opens a **second**, redundant tab
next to the rule's blank one (the exact symptom `switch_to_workspace_for_browser`
was written to prevent, just one layer down). Fixed by giving `open_browser_url`
an `await_cold_tab` flag (`open_browser_url "$url" 1`): when the caller has just
seen `rule_browser_addr` set (i.e. it knows the empty tab exists but may not be
indexed yet), it polls `empty_browser_tab_id` for up to ~1.2s instead of
checking once. Only the two rule-aware call sites (`open_in_new_browser_window`,
`open_or_focus_url`'s `cold` branch) pass `1`; other callers keep the single
check so they don't pay that wait when there's genuinely no empty tab to find.

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
via **bruvtab** (`bruvtab list` → `bruvtab activate --focused`) rather than
duplicating it.

Tab reuse is a 3-tier match in `open_or_focus_url` (`scripts/lib.sh`); the
bookmark's display name is threaded in from `bookmarks.sh` for tier 2:

0. **exact normalized URL** (scheme + trailing `/` + `#fragment` stripped) —
   covers the common case (Reverso, Gemini on a direct link).
1. **same hostname** — covers same-site path/query drift (YouTube
   `.../watch?v=…` vs bookmark `.../playlist?list=WL`).
2. **exact tab title == bookmark name** (fallback only) — covers cross-host
   redirects, e.g. the `chat.openai.com/chat` bookmark matching a live tab at
   `chatgpt.com/`, where only the title survives the redirect. `search.sh` does
   not pass a name, so it stops at the URL/host tiers.

If none match, a new tab is opened.

⚠️ Gotcha (bruvtab): `bruvtab` is an optional dependency (uv tool/pipx),
requires the bruvtab extension and native-messaging manifest to be installed for
Helium. Without it — fallback to launching the URL with `helium-browser`.
`bruvtab activate --focused` on Hyprland doesn't raise the window itself, so the
window is raised manually — `focus_browser_for_title` finds the window by tab
title (the tab title becomes the window title after activation), so that the tab
on the YouTube ws wins, not some random other browser window. `lib.sh` filters
bruvtab prefixes to Helium/Chromium-like clients so a leftover Firefox bruvtab
client cannot steal a migrated open.

- Sources: its own `bookmarks.tsv`, the private dotfiles-private, and an
  auto-export of Helium bookmarks (`export_browser_bookmarks`) from
  `~/.config/net.imput.helium/Default/Bookmarks`. This is Chromium JSON, not
  Firefox `places.sqlite`, so `jq` is used and duplicate URLs are dropped.
  Redirected bookmark URLs (e.g. `chat.openai.com/chat` → `chatgpt.com/`) are
  still reused via the title tier instead of opening a duplicate; the browser's
  `Bookmarks` JSON is the canonical source, so fixing a URL there (not the
  exported TSV, which regenerates) is the durable fix.
- New tabs are **never** opened on the YouTube workspace (ws4):
  `prepare_browser_for_new_tab` picks a `tab`/`newwindow`/`cold` strategy.
- Recents log same as in apps.sh: empty query → recently opened.

### search.sh — web search (split out of bookmarks.sh)

**Why it's separate from bookmarks.sh** (commit "split web search into
search.sh"): the "search the web" address-bar-like half was carved out into its
own independent QAT with no bookmark rows — bookmarks.sh now only searches
bookmarks. You type a query → live Google suggestions
(`suggestqueries.google.com`) → Enter on a suggestion or on your raw query opens
the search in Helium (same bruvtab logic as bookmarks.sh). The Google
suggestions URL still uses `client=firefox`; that is only Google's response
format selector, not a local Firefox dependency.

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
  OAuth). `yt-dlp` does not support `helium` as a browser name, so the Chromium
  extractor is pointed at Helium's profile path.
- `-s` live search: Enter on an empty query opens the page matching the active
  mode — Watch Later for Videos, `youtube.com/feed/channels` for Channels,
  History for History, and the WL playlist in Watch Later mode. This keeps the
  picker useful as a quick route to the corresponding full YouTube view when no
  item is selected. Otherwise, Enter with no results opens the corresponding
  full YouTube view with the typed query: regular results for Videos or
  channel-filtered results for Channels (an `enter:transform` bind checks `{}`
  for emptiness). History and Watch Later have no reliable URL-addressable video
  filter, so filtering those feeds remains local to the picker; their no-result
  fallbacks open the corresponding unfiltered feed pages. ⚠️ Gotcha: the
  fallback sentinel must stay a plain two-field row, not the usual 6-column
  shape — `IFS=$'\t' read` collapses _consecutive_ tab delimiters (tab is
  IFS-whitespace), so extra empty columns would swallow the payload into
  nothing.

⚠️ Gotcha (cache/preview): the preview makes **no** network requests on hover —
everything comes from the already-built TSV; the thumbnail is downloaded once
and cached in `~/.cache/youtube-fzf/thumbs`. Fallback order is
`hqdefault→mqdefault→default` (hqdefault always exists). The preview function
runs as a subprocess (the `--preview` branch) and doesn't depend on the rest of
the script.
