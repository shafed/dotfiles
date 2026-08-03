---
title: index
type: index
updated: 2026-07-09
---

# Dotfiles wiki — index

Knowledge base for these dotfiles. Answers the question **"why is it done this
way"** and describes the design of non-trivial parts (primarily `scripts/`).
Maintenance rules — in [CONVENTIONS](CONVENTIONS.md). Rules for the agent — in
[../AGENTS.md](../AGENTS.md).

Status: 🚧 all pages have brief content (first pass by agents on 2026-07-01); to
be deepened as edits happen. Legend: ✅ filled in · 🚧 partial · 🌱 stub.

## Setup

| Page                         | What it covers                                                                                                           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 🚧 [bootstrap](bootstrap.md) | Deploying on a new machine: `bootstrap.sh` checks required packages and symlinks `~/.config/<tool> → ~/dotfiles/<tool>`. |

## Components

| Page                     | Covers     | What it covers                                                                                                                                                                            |
| ------------------------ | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🚧 [kanata](kanata.md)   | `kanata/`  | Keyboard layers, opposite-hand HRM, chords, kitty-send instead of a tmux prefix, xkb US-wrap for symbols. The most thought-through and fragile part of the keymap.                        |
| 🚧 [scripts](scripts.md) | `scripts/` | fzf pickers (apps/bookmarks/search/youtube) on a shared `lib.sh`; training logbook (`generate_logbook.py`); daily-notes; nvim-edit-handler. The most active and complex part of the repo. |
| 🚧 [hypr](hypr.md)       | `hypr/`    | Hyprland: bindings, monitors, exec-at-launch, hypridle/hyprlock/hyprsunset.                                                                                                               |
| 🚧 [kitty](kitty.md)     | `kitty/`   | Terminal: native sessions, quick-access-terminal, pass_keys, themes (gruvbox). Large config — mostly commented-out defaults.                                                   |
| 🚧 [nvim](nvim.md)       | `nvim/`    | LazyVim base, custom plugins/snippets, logbook integration, harper exceptions.                                                                                                            |
| 🚧 [zsh](zsh.md)         | `zsh/`     | oh-my-zsh, aliases, functions (yazi cd, im-select), aichat.                                                                                                                               |
| 🚧 [waybar](waybar.md)   | `waybar/`  | Status bar for Hyprland.                                                                                                                                                                  |
| 🚧 [yazi](yazi.md)       | `yazi/`    | File manager: plugins, flavors, keymap.                                                                                                                                                   |

## Cross-cutting

| Page                       | What it covers                                                                                                                           |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| 🚧 [keymap](keymap.md)     | End-to-end key map: how kanata layers, hypr bindings, and kitty hotkeys combine without conflicting. Single source of truth for hotkeys. |
| 🚧 [sessions](sessions.md) | Native kitty sessions (migration from tmux): kanata sends C-S- hotkeys, kitty-zoxide-session, obsidian session for the logbook.          |
| 🚧 [theming](theming.md)   | Gruvbox dark everywhere (palette copied in each component); no dynamic light/dark (darkman scaffolding empty, hyprsunset is gamma only). |

## Global

| Page                   | What it covers                                                                                                                                                                |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ✅ [global](global.md)     | System-level decisions outside config components: the shared `instructions.md` (global agent instructions, symlinked to claude/opencode/codex) and the home directory layout. |

## Decisions

| Page                         | What it covers                                                                                                                                                                                                                                              |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🚧 [decisions](decisions.md) | Major decisions and rejected alternatives: Firefox → Helium default browser; tmux → kitty native sessions; kanata as the single keymap engine; removal of Windows/WSL legacy; manual symlinks → bootstrap.sh (plain symlinks; GNU Stow tried and rejected). |
