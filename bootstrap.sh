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
  "kanata:kanata (AUR)"
  "kitty:kitty"
  "helium-browser:helium-browser-bin (AUR)"
  "waybar:waybar"
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
  "brotab:brotab (pipx/AUR)"
  "task:taskwarrior"
  "copyq:copyq"
  "python3:python"
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

link_configs() {
  echo
  echo "== Linking configs into ~/.config =="
  mkdir -p "$HOME/.config"

  # Whole-directory symlinks: ~/.config/<name> -> ~/dotfiles/<name>
  local config_dirs=(
    hypr kitty nvim kanata waybar yazi darkman lazygit sioyek zathura systemd
  )
  for name in "${config_dirs[@]}"; do
    if [ -d "$name" ]; then
      ln -sfvn "$DOTFILES_DIR/$name" "$HOME/.config/$name"
    fi
  done

  echo
  echo "== Linking zsh files into \$HOME =="
  ln -sfv "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
  ln -sfv "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"

  echo
  echo "== Installing ~/.local/bin wrappers =="
  mkdir -p "$HOME/.local/bin"
  cat >"$HOME/.local/bin/sudo" <<EOF
#!/usr/bin/env bash
exec "$DOTFILES_DIR/scripts/sudo-notify.sh" "\$@"
EOF
  chmod +x "$HOME/.local/bin/sudo"
  echo "  wrote $HOME/.local/bin/sudo"
}

[ "$DO_CHECK" -eq 1 ] && check_requirements
[ "$DO_LINK" -eq 1 ] && link_configs

echo
echo "Done."
