---
title: nvim-clipboard
type: component
updated: 2026-08-14
covers:
  - nvim/lua/config/keymaps.lua
  - nvim/lua/utils/tasks.lua
  - nvim/lua/plugins/mini-files.lua
---

# nvim — clipboard, registers, mini.files

Parent: [nvim](nvim.md). Pairs with the Downloads watcher in
[scripts-misc](scripts-misc.md).

## Clipboard vs. registers (`keymaps.lua`, `utils/tasks.lua`)

`clipboard=""` (`options.lua`) is deliberate: plain `y`/`d`/`ciw`/`x` etc. stay
in Neovim's own unnamed register and never touch the system clipboard, so
ordinary edits don't spam `+` with unrelated text across other apps/sessions.
Explicit `"+`-prefixed mappings are used wherever system-clipboard interop is
actually wanted:

- `<leader>y`/`<leader>Y` — yank (line/to-EOL) to `+`.
- `<leader>p`/`<leader>P` — paste from `+`.
- `<leader>d` — delete to the black hole register (`"_d`), i.e. real "no yank".
- Visual `y` — in markdown, pipes the selection through
  `prettier --prose-wrap never` before landing it in `+`, so hard-wrapped
  paragraph text pastes as unwrapped lines elsewhere; non-markdown just does a
  plain `"+y`.
- Mouse selection (`<LeftRelease>`/`<2-LeftRelease>`) auto-yanks to `+`.

⚠️ Gotcha: an earlier attempt bound a standalone `<leader>x` for "cut" (delete +
copy to `+`), but LazyVim/Trouble already owns `<leader>x` as a which-key group
(`xx`, `xl`, `xq`, `xt`, ...) — a bare `<leader>x` mapping doesn't break those,
but which-key has to wait out `timeoutlen` to disambiguate, so the cut fires
late instead of failing outright. Current approach avoids a dedicated cut
mapping entirely (see below).

⚠️ Gotcha (fixed 2026-07-05): a `FocusLost`/`QuitPre`/`VimSuspend`/`VimLeavePre`
autocmd used to copy `"` into `+` whenever a session lost focus or exited, so
the last yank/delete was available via `<leader>p`/system paste elsewhere
without making every `ciw`/`dd` hit the clipboard live. Removed: `FocusLost` is
a terminal-window focus event, not a "this kitty session became inactive" event,
so switching between kitty sessions (`goto_session`) doesn't reliably fire it
for the session being left — it can fire late, or fire for a background session
instead, so the wrong (stale) session's register would silently land in `+`.
Cross-session clipboard transfer now relies solely on the explicit mappings
above (`<leader>y`, mouse-select) instead of a focus-event heuristic.

`tasks.yank_text` (bound to `<leader>yI` — capital `I` for "Item") copies **any
Markdown item** — task bullet, plain bullet, heading, blockquote — without its
structural prefix, straight to `+`. `parse_prefix` strips indentation, `>` quote
markers, `-`/`*`/`+`/`1.` list markers, `[ ]`/`[x]`/`[-]`/`[!]` etc. checkboxes,
and `#` heading markers. It shares the chunk-boundary walk with `toggle_done`:
an item's text can wrap onto following non-bullet, non-blank lines (e.g. a long
todo in `todos.md`), so it selects and yanks the whole wrapped chunk, not just
the cursor's physical line. Visual `<leader>yI` yanks every selected line,
stripping the prefix independently from each. The yanked range is flashed
briefly (see `flash_range` in `utils/tasks.lua`).

`mini.files` has its own file-clipboard interop. `<leader>y` copies selected
paths as `text/plain` + `text/uri-list`; for a single image it additionally puts
the actual `image/*` bytes on the clipboard so Claude/browser paste treats it as
an image. `<leader>p` reads `text/uri-list` and copies those files into the
current mini.files directory. This pairs with the Downloads watcher described in
[scripts](scripts.md).

**Image preview in mini.files** (`<leader>ip`): mini.files' built-in preview
pane can't render binary images, so the keymap opens the image under the cursor
in a centered float rendered by the Snacks image module
(`Snacks.image.placement.new`, kitty graphics protocol — kitty-only, since the
terminal is kitty). The window opens at a max area and is then shrunk to hug the
image once its size is known (the placement's `on_update`, the same resize trick
as Snacks' own doc hover), with a footer listing filename, pixel resolution
(ImageMagick `identify`) and size in MB. Non-image files are rejected with a
notify. `q`/`<Esc>` closes the float. Port of linkarzu's `image.nvim`-based
popup to Snacks.

- ⚠️ Gotcha: mini.files tracks "lost focus" with a 1 s timer
  (`H.explorer_track_lost_focus` in `mini/files.lua`) and closes the explorer if
  the _current_ buffer's filetype is not `minifiles` — so a focused preview
  float would kill the explorer ~1 s after opening. There's no public option to
  disable that. Workaround: the preview buffer is deliberately given
  `filetype = "minifiles"` (not `"image"`) — the timer sees a minifiles buffer
  and skips, while the Snacks placement renders the image regardless of
  filetype. Side effect: LazyVim injects its `ft = "minifiles"` keymaps into the
  float; `<leader>ip` there is handled as a close-toggle. The float takes focus
  (`enter = true`), `q`/`<Esc>` close it, focus then returns to the explorer.
  `<leader>ip` is a toggle from the explorer too — the same entry closes the
  preview, a different entry replaces it.

⚠️ Gotcha (fixed 2026-08-01): mini.files ≥ 0.18.0 notifies LSP servers about
file actions via `workspace/*Files`, and its hook assumes every advertised
filter has a string `scheme`. Some servers send `"scheme": null` (also
`"matches": null`), which Neovim decodes to the `vim.NIL` sentinel (userdata),
so the hook's `scheme .. ':'` threw E5108 on every file operation in the
explorer. `init` in `plugins/mini-files.lua` now normalizes `vim.NIL` → `nil` in
each client's `server_capabilities.workspace.fileOperations` on `LspAttach` (and
existing clients), so null filters behave as "no filter". Upstream unfixed as of
0.18.0.
