#!/usr/bin/env bash
set -euo pipefail

if command -v yay >/dev/null 2>&1; then
  echo "yay already installed: $(command -v yay)"
  exit 0
fi

if [ ! -e /etc/arch-release ]; then
  echo "yay bootstrap supports Arch only" >&2
  exit 2
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "yay bootstrap must run as a regular user, not root" >&2
  exit 2
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "yay bootstrap needs pacman" >&2
  exit 2
fi
if ! command -v sudo >/dev/null 2>&1; then
  echo "yay bootstrap needs sudo" >&2
  exit 2
fi

bootstrap_packages=()
if ! command -v git >/dev/null 2>&1; then
  bootstrap_packages+=(git)
fi
if ! pacman -Q base-devel >/dev/null 2>&1; then
  bootstrap_packages+=(base-devel)
fi

if [ "${#bootstrap_packages[@]}" -gt 0 ]; then
  echo "Installing yay build prerequisites: ${bootstrap_packages[*]}"
  sudo pacman -S "${bootstrap_packages[@]}"
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is still unavailable after installing bootstrap prerequisites" >&2
  exit 2
fi
if ! command -v makepkg >/dev/null 2>&1; then
  echo "makepkg is unavailable after installing base-devel" >&2
  exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Bootstrapping yay from the AUR..."
git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
(
  cd "$tmp/yay"
  makepkg -si
)

if ! command -v yay >/dev/null 2>&1; then
  echo "yay bootstrap completed but yay is not in PATH" >&2
  exit 1
fi

echo "yay bootstrap complete: $(command -v yay)"
