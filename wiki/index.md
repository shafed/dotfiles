---
title: index
type: index
updated: 2026-08-30
---

# Dotfiles wiki — index

Why things are done this way, not how they work — the code is the source of
truth for how. Schema and writing rules: [CONVENTIONS](CONVENTIONS.md). Agent
rules: [../CLAUDE.md](../CLAUDE.md) (`AGENTS.md` symlinks to it).

## Setup

- **[bootstrap](bootstrap.md)** — deploying on a new machine; `./dots apply` is
  the primary entrypoint and `bootstrap.sh` is only a compatibility wrapper.
- **[dots](dots.md)** — installed CLI for apply/doctor/check, migrations,
  desktop controls and diagnostics.

## Components

- **[kanata](kanata.md)** — keyboard layers, home-row mods, chords. The most
  fragile part of the keymap.
- **[scripts](scripts.md)** — map of content: fzf pickers, the self-pasting
  scratch note, training logbook, standalone helpers. The most active and
  gotcha-dense part of the repo.
- **[hypr](hypr.md)** — Hyprland: bindings, monitors, idle/lock/gamma.
- **[quickshell](quickshell.md)** — active top bar and desktop shell; modular
  QML, realtime services, picker integration and runtime-cache layout.
- **[kitty](kitty.md)** — terminal: QAT panels, custom kittens, remote control.
- **[nvim](nvim.md)** — map of content: which LazyVim behavior was overridden
  and why — window UI, vault workflows, clipboard, Russian layout.
- **[zsh](zsh.md)** — shell config, aliases, functions.
- **[yazi](yazi.md)** — file manager.
- **[sioyek](sioyek.md)** — PDF viewer; why every launcher must go through the
  `~/.local/bin/sioyek` wrapper.

## Cross-cutting

- **[keymap](keymap.md)** — single source of truth for hotkeys: how kanata,
  hypr, and kitty divide the keyboard without colliding.
- **[sessions](sessions.md)** — native kitty sessions after the tmux removal.
- **[theming](theming.md)** — `colors.toml` source-of-truth, generated Gruvbox
  surfaces, and what darkman does and does not switch.

## Global

- **[global](global.md)** — agent instruction files, the commit convention, home
  layout.
- **[cli-agents](cli-agents.md)** — sharing config between Claude Code, Codex,
  and opencode without writing it twice.

## Decisions

- **[decisions](decisions.md)** — major decisions and the alternatives that were
  rejected, with reasons.
