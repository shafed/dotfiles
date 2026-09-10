---
title: scripts-logbook
type: component
updated: 2026-09-10
covers:
  - scripts/generate_logbook.py
  - scripts/nvim-edit-handler.sh
---

# scripts — training logbook

Parent: [scripts](scripts.md). The editing side lives in [nvim](nvim.md); the
kitty session it opens into is in [sessions](sessions.md).

Markdown training sessions in `~/github/obsidian/training/` become one generated
`training/logbook.html`, with links back into Neovim for editing source notes.

## generate_logbook.py

Generates a self-contained `logbook.html` from the markdown sessions in the
vault. CSS and JavaScript are inlined, exercise data is injected into the page,
and the output stays inside the vault so Syncthing/NAS carries the regenerated
file to other devices.

Current behavior:

- Output defaults to `~/github/obsidian/training/logbook.html`; override with
  `LOGBOOK_OUTPUT`.
- Canonical session filenames are `YYYY-MM-DD-Training.md`. Legacy
  `YYYY-MM-DD-Day-N.md` files remain readable.
- Session mood is read from YAML frontmatter as `mood: bad|mid|great`.
- Feed search ranks exact/substring/token matches and debounces input before
  updating results.
- Fuzzy matching is applied per word rather than across one concatenated card.
- The search value is shared between feed and exercise-list views.
- Typing a new query while exercise detail is open returns to the filtered
  exercise list.
- Date fragments such as `2026 06` match June 2026 sessions.
- Exercise names open their history; the exercise list is ordered by last use.
- `training/events.md` accepts entries shaped
  `YYYY-MM-DD: #bad|#neutral|#good text`, including wrapped continuation lines.
- Session links use `nvim-edit://<percent-encoded absolute path>` to open the
  source markdown note.

## nvim-edit-handler.sh

Handles `nvim-edit://` links from the logbook and opens the source markdown file
in the kitty `obsidian` session.

It focuses or creates the main Obsidian kitty session through
`kitty-zoxide-session.sh --named obsidian`, then prefers Neovim remote-tab over
the active Neovim socket. If remote-tab is unavailable, it falls back to kitty
`send-text` and opens the file in the running editor or shell.

## Connections

- `generate_logbook.py` writes `training/logbook.html` inside the vault.
- `obsidian.regenerate_logbook()` invokes the generator from Neovim.
- `<leader>lr` regenerates the logbook manually.
- `<leader>lp` saves a training note and regenerates the logbook automatically.
- `<leader>lv` opens the generated HTML.
- `nvim-edit-handler.sh` opens source notes from `nvim-edit://` links.
- Syncthing/NAS carries the generated HTML and source notes to other devices.
