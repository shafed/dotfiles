#!/usr/bin/env bash
# Bootstrap this dotfiles repo on a new Arch Linux + Hyprland machine.
# Symlinks configs into ~/.config and reports missing packages.
#
# Usage:
#   ./bootstrap.sh            # check requirements, then link everything
#   ./bootstrap.sh --check    # only check requirements, don't link
#   ./bootstrap.sh --link     # only link, skip requirement check
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

DO_CHECK=1
DO_LINK=1
case "${1:-}" in
--check) DO_LINK=0 ;;
--link) DO_CHECK=0 ;;
esac

# Required commands, and the pacman/AUR package that provides them.
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

# Sources this script links, relative to DOTFILES_DIR. CONFIG_DIRS become
# whole-directory symlinks into ~/.config; LINK_FILES are individual symlinks.
CONFIG_DIRS=(
  hypr kitty nvim kanata quickshell yazi darkman lazygit sioyek zathura systemd
)
LINK_FILES=(
  zsh/zshrc
  zsh/zprofile
  instructions.md
  scripts/sudo-notify.sh
)

check_requirements() {
  echo "== Checking required commands =="
  local missing=()
  for entry in "${REQUIRED_PKGS[@]}"; do
    local cmd="${entry%%:*}"
    local pkg="${entry#*:}"
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "  ok    $cmd"
    else
      echo "  MISSING $cmd  (package: $pkg)"
      missing+=("$pkg")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    echo
    echo "Missing ${#missing[@]} package(s). Install before/after linking as needed:"
    printf '  - %s\n' "${missing[@]}"
  else
    echo
    echo "All required commands found."
  fi
}

check_sources() {
  echo "== Checking link sources exist in the repo =="
  local missing=0
  local name src
  for name in "${CONFIG_DIRS[@]}"; do
    if [ ! -d "$name" ]; then
      echo "  MISSING dir  $name/  (would link ~/.config/$name)"
      missing=1
    fi
  done
  for src in "${LINK_FILES[@]}"; do
    if [ ! -e "$src" ]; then
      echo "  MISSING file $src  (linked by bootstrap)"
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    echo "  Fix or remove the missing sources, then re-run."
    return 1
  fi
  echo "  all sources present."
}

link_configs() {
  echo
  check_sources

  echo
  echo "== Linking configs into ~/.config =="
  mkdir -p "$HOME/.config"

  # Whole-directory symlinks: ~/.config/<name> -> this worktree/repo.
  for name in "${CONFIG_DIRS[@]}"; do
    ln -sfvn "$DOTFILES_DIR/$name" "$HOME/.config/$name"
  done

  echo
  echo "== Linking zsh files into \$HOME =="
  ln -sfv "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
  ln -sfv "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"

  echo
  echo "== Linking CLI agent instruction files =="
  mkdir -p "$HOME/.claude" "$HOME/.config/opencode" "$HOME/.codex"
  ln -sfv "$DOTFILES_DIR/instructions.md" "$HOME/.claude/CLAUDE.md"
  ln -sfv "$DOTFILES_DIR/instructions.md" "$HOME/.config/opencode/AGENTS.md"
  ln -sfv "$DOTFILES_DIR/instructions.md" "$HOME/.codex/AGENTS.md"

  mkdir -p "$HOME/.claude/hooks"
  ln -sfv "$DOTFILES_DIR/.claude/hooks/no-coauthor.sh" "$HOME/.claude/hooks/no-coauthor.sh"
  ln -sfvn CLAUDE.md "$DOTFILES_DIR/AGENTS.md"
  ln -sfvn ../../.claude/skills/commit "$DOTFILES_DIR/.agents/skills/commit"

  mkdir -p "$HOME/.claude/themes"
  ln -sfvn "$DOTFILES_DIR/.claude/themes/gruvbox-material.json" \
    "$HOME/.claude/themes/gruvbox-material.json"

  echo
  echo "== Linking darkman hook scripts into \$XDG_DATA_HOME =="
  mkdir -p "$HOME/.local/share"
  ln -sfvn "$DOTFILES_DIR/darkman/scripts" "$HOME/.local/share/darkman"

  echo
  echo "== Installing ~/.local/bin wrappers =="
  mkdir -p "$HOME/.local/bin"

  cat >"$HOME/.local/bin/sudo" <<EOF
#!/usr/bin/env bash
exec "$DOTFILES_DIR/scripts/sudo-notify.sh" "\$@"
EOF
  chmod +x "$HOME/.local/bin/sudo"
  echo "  wrote $HOME/.local/bin/sudo"

  # sioyek can't create a Qt6 EGL context on nvidia under Wayland, so force it
  # onto XWayland. This is a wrapper rather than an alias so every caller gets it.
  cat >"$HOME/.local/bin/sioyek" <<EOF
#!/usr/bin/env bash
exec env -u LIBGL_ALWAYS_SOFTWARE QT_QPA_PLATFORM=xcb /usr/bin/sioyek "\$@"
EOF
  chmod +x "$HOME/.local/bin/sioyek"
  echo "  wrote $HOME/.local/bin/sioyek"

  # Quickshell owns org.freedesktop.Notifications. Dunst is D-Bus-activatable,
  # so disabling it is insufficient: mask it to prevent it from stealing the
  # notification name after a notify-send.
  if systemctl --user list-unit-files dunst.service >/dev/null 2>&1; then
    systemctl --user mask --now dunst.service >/dev/null 2>&1 || true
    echo "  masked dunst.service (Quickshell notifications)"
  fi

  systemctl --user daemon-reload >/dev/null 2>&1 || true
}

[ "$DO_CHECK" -eq 1 ] && check_requirements
[ "$DO_CHECK" -eq 1 ] && check_sources
[ "$DO_LINK" -eq 1 ] && link_configs

echo
echo "Done."
