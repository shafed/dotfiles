---
title: nvim-telegram
type: component
updated: 2026-09-19
covers:
  - nvim/lua/plugins/telegram.lua
---

# nvim — telegram.nvim

Parent: [nvim](nvim.md). This is the Telegram **client inside Neovim**
(`ChuYanLon/telegram.nvim`, a TDLib server spawned via `npx tsx`); the desktop
app's day/night palettes are a separate topic in [telegram](telegram.md).

## API credentials live outside the repo

`api_id`/`api_hash` are read at load time from
`~/.config/telegram-nvim/secret.lua` (mode `600`), not from this repo.

The obvious spot — a file under `~/.config/nvim/` — does **not** work: that path
is a symlink to `../nvim`, so anything placed there is inside a public
repository. Hence a separate `~/.config/telegram-nvim/` directory.

⚠️ Gotcha: with the file missing the plugin still starts, but falls back to the
`api_id` hardcoded in its own `src/client.ts`, which belongs to the plugin
author. Telegram terminates sessions opened that way: the login succeeds, then
TDLib flips to `authorizationStateLoggingOut`, the UI reports "Session closed
from another device" and asks for the phone number again. The plugin never calls
`logOut` itself, so that state always means the server ended the session. On a
new machine, create the file from <https://my.telegram.org> before concluding
the plugin is broken.

## Why the config patches the plugin at runtime

Four upstream bugs are worked around in `config`, by wrapping the plugin's own
functions rather than editing `~/.local/share/nvim/lazy/telegram.nvim/` — lazy
checks out over local edits on update, and a dirty tree blocks it.

- **`data_dir` moved out of the plugin directory.** It defaults to the plugin's
  own folder, so `:Lazy clean` or a reinstall takes the Telegram session with
  it.
- **Longer timeout for `/chats`, `/groups`, `/chats/saved`.** Every request is
  capped at `--max-time 5`, but the first `/chats` walks the whole chat list
  through `getChat` one at a time and takes ~17 s here. curl aborts with an
  empty body, which surfaces as `connection failed after 4 retries` and `No
chats found` while the server is perfectly healthy and the account is
  authorized. The server caches the list, so only the first call after a server
  start is slow.
- **SIGINT instead of SIGTERM when stopping the server.** Its `SIGTERM` handler
  exits without awaiting `tgClient.shutdown()`, so TDLib never receives `close`
  and `td.binlog` is not flushed; only `SIGINT` logs `Shutting down...`. Both
  `jobstop()` and `kill` send SIGTERM, so the wrapper signals the port's
  listener itself — after checking via `ps` that it is our server, never
  whoever else holds the port.
- **The session database is shielded from the auth poller.** A failed auth poll
  deletes `tdlib_db`/`tdlib_files` unconditionally, so a transient failure — or
  simply pressing Esc at the phone/code prompt — destroys a working login. The
  wrapper stashes the directories across that callback; `:TgLogout` remains the
  only way to actually clear them.

⚠️ Gotcha: all four wrap internals (`auth.auth_poll`, `server.stop_server`,
`server.get_chats` and friends). After updating telegram.nvim, verify those
names still exist — a rename makes the wrapper silently stop applying, and the
first symptom is the session vanishing again.

## Chat list

The all-chats view already exists upstream: `@` inside the chat window opens the
tool picker, where `chats` switches chat, `showarchived` folds archived ones in
and `folder` switches Telegram folders. `show_group_selector` in the plugin's
`ui.lua` is dead code — defined, never bound — so don't go looking for the
keymap that calls it.
