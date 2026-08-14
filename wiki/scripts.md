---
title: scripts
type: moc
updated: 2026-08-14
covers:
  - scripts/
---

# scripts

Map of content — `scripts/` is the most active and gotcha-dense part of the
repo, so it is split by what you'd come here to find out.

- **[scripts-pickers](scripts-pickers.md)** — the fzf pickers
  (`apps`/`bookmarks`/`search`/`youtube`) and the shared `lib.sh` engine behind
  them. Start here for anything about the quick-access panels: why they're
  long-lived, how they talk to the main kitty, and why a picker must never
  spawn a terminal of its own.
- **[scripts-scratch](scripts-scratch.md)** — `SUPER+N`, the floating scratch
  note that pastes itself into whatever was focused before. Reuses the panel
  mechanism above; carries the heaviest gotchas in the repo (layer-shell input
  capture, systemd scope teardown).
- **[scripts-logbook](scripts-logbook.md)** — `generate_logbook.py` and the
  `nvim-edit://` handler: markdown training sessions → a single self-contained
  `logbook.html`, and the link back into nvim for editing one.
- **[scripts-misc](scripts-misc.md)** — unrelated one-offs: the Downloads
  clipboard watcher, the `sudo` notify wrapper, the obsidian git sync,
  daily notes, and the kanata layout forcer.

⚠️ Two conventions hold across all of them, and breaking either is silent:

- Everything a script launches gets `</dev/null` and `disown`. A QAT panel stays
  open while any process holds its tty, so a browser tied to that tty dies when
  the panel is force-closed.
- Browser identity (`helium-browser`, Hyprland class `helium`, profile path) is
  centralized in `lib.sh`. Don't re-inline it per script — that is exactly what
  the Firefox → Helium migration had to undo ([decisions](decisions.md)).
