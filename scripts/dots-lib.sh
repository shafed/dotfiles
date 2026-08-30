#!/usr/bin/env bash

DOTS_ROOT="${DOTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

REQUIRED_PKGS=(
  "hyprland:hyprland"
  "uwsm:uwsm"
  "kanata:kanata-bin (AUR)"
  "kitty:kitty"
  "helium-browser:helium-browser-bin (AUR)"
  "quickshell:quickshell"
  "wpctl:wireplumber"
  "nmcli:networkmanager"
  "bluetoothctl:bluez-utils"
  "powerprofilesctl:power-profiles-daemon"
  "brightnessctl:brightnessctl"
  "checkupdates:pacman-contrib"
  "wl-paste:wl-clipboard"
  "cliphist:cliphist"
  "yazi:yazi"
  "nvim:neovim"
  "zsh:zsh"
  "zoxide:zoxide"
  "fzf:fzf"
  "jq:jq"
  "darkman:darkman (AUR)"
  "lazygit:lazygit"
  "sioyek:sioyek"
  "yt-dlp:yt-dlp"
  "bruvtab:bruvtab (uv tool/pipx)"
  "task:taskwarrior"
  "python3:python"
)

OPTIONAL_PKGS=(
  "luac:lua (for dots check)"
  "pre-commit:pre-commit (for local hooks)"
)

CONFIG_DIRS=(
  hypr kitty nvim kanata quickshell yazi darkman lazygit sioyek zathura systemd
)

LINK_FILES=(
  zsh/zshrc
  zsh/zprofile
  instructions.md
  scripts/sudo-notify.sh
  .claude/hooks/no-coauthor.sh
  .claude/themes/gruvbox-material.json
  darkman/scripts
  dots
)

DOTS_MANAGED_LINKS=(
  "zsh/zshrc|$HOME/.zshrc"
  "zsh/zprofile|$HOME/.zprofile"
  "instructions.md|$HOME/.claude/CLAUDE.md"
  "instructions.md|$HOME/.config/opencode/AGENTS.md"
  "instructions.md|$HOME/.codex/AGENTS.md"
  ".claude/hooks/no-coauthor.sh|$HOME/.claude/hooks/no-coauthor.sh"
  ".claude/themes/gruvbox-material.json|$HOME/.claude/themes/gruvbox-material.json"
  "darkman/scripts|$HOME/.local/share/darkman"
  "dots|$HOME/.local/bin/dots"
)

DOTS_CORE_USER_SERVICES=(
  quickshell.service
  kanata.service
  darkman.service
)
