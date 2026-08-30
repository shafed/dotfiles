#!/usr/bin/env bash

DOTS_ROOT="${DOTS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DOTS_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DOTS_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

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
  "instructions.md|$DOTS_CONFIG_HOME/opencode/AGENTS.md"
  "instructions.md|$HOME/.codex/AGENTS.md"
  ".claude/hooks/no-coauthor.sh|$HOME/.claude/hooks/no-coauthor.sh"
  ".claude/themes/gruvbox-material.json|$HOME/.claude/themes/gruvbox-material.json"
  "darkman/scripts|$DOTS_DATA_HOME/darkman"
  "dots|$HOME/.local/bin/dots"
)

DOTS_CORE_USER_SERVICES=(
  quickshell.service
  kanata.service
  darkman.service
)

# name|usage|description. Keep this small: it is both human help and the
# machine-readable command catalog used by `dots commands --json`.
DOTS_COMMANDS=(
  "apply|dots apply [--check|--links-only]|Apply the current checkout to this machine"
  "doctor|dots doctor|Check installed dotfiles and machine state"
  "check|dots check [all|shell|lua|python|tests]|Run repository checks"
  "migrate|dots migrate [--check]|Detect or apply safe stale-state migrations"
  "theme|dots theme [status|light|dark|toggle]|Show or switch the darkman theme"
  "restart|dots restart <quickshell|kanata|darkman|all>|Restart managed user services"
  "refresh|dots refresh <quickshell|systemd|all>|Rebuild derived state and reload services"
  "shell|dots shell <apps|bookmarks|clipboard|hotkeys|system|refresh|panel ...>|Control stable Quickshell actions"
  "panel|dots panel <system|audio|network|bluetooth|power|agents|updates|notifications|calendar>|Toggle a Quickshell panel"
  "debug|dots debug [--no-logs]|Print a compact diagnostic bundle"
  "commands|dots commands [--json]|List commands and machine-readable metadata"
  "help|dots help [command]|Show CLI or command help"
)

dots_print_commands() {
  local entry rest name description
  for entry in "${DOTS_COMMANDS[@]}"; do
    name="${entry%%|*}"
    rest="${entry#*|}"
    description="${rest#*|}"
    printf '  %-10s %s\n' "$name" "$description"
  done
}

dots_json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

dots_print_commands_json() {
  local entry rest name usage description first=1
  printf '[\n'
  for entry in "${DOTS_COMMANDS[@]}"; do
    name="${entry%%|*}"
    rest="${entry#*|}"
    usage="${rest%%|*}"
    description="${rest#*|}"
    if [ "$first" -eq 0 ]; then
      printf ',\n'
    fi
    first=0
    printf '  {"name":'
    dots_json_string "$name"
    printf ',"usage":'
    dots_json_string "$usage"
    printf ',"description":'
    dots_json_string "$description"
    printf '}'
  done
  printf '\n]\n'
}
