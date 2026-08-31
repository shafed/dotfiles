---
title: index
type: index
updated: 2026-08-31
---

# Dotfiles wiki — index

Why things are done this way, not how they work — the code is the source of
truth for how. Schema and writing rules: [CONVENTIONS](CONVENTIONS.md). Agent
rules: [../CLAUDE.md](../CLAUDE.md) (`AGENTS.md` symlinks to it).

## Setup

- **[bootstrap](bootstrap.md)** — deploying on a new machine via `./dots apply`.
- **[dots](dots.md)** — CLI for plan/apply, drift, dry-run provisioning,
  staging, doctor, history/rollback and desktop controls.
- **[profiles](profiles.md)** — desired-state composition (`base`, `desktop`,
  `laptop`, `ai`), per-machine selection and capabilities.

## Components

- **[kanata](kanata.md)** — keyboard layers, home-row mods, chords. The most
  fragile part of the keymap.
- **[scripts](scripts.md)** — map of content: fallback fzf/QAT pickers, training
  logbook, legacy scratch helpers and standalone integrations.
- **[hypr](hypr.md)** — Hyprland: bindings, monitors, idle/lock/gamma.
- **[quickshell](quickshell.md)** — active top bar and desktop shell; modular
  QML, realtime services, Applications/Bookmarks/Projects/Sessions/YouTube,
  keyboard clipboard and scratch overlays.
- **[kitty](kitty.md)** — terminal: sessions, legacy/manual QAT panels, custom
  kittens and remote control.
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
