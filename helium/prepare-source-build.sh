#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$ROOT/helium/gruvbox-exact-tabs.patch"
PATCH_REL="helium/linux/gruvbox-exact-tabs.patch"

usage() {
  cat <<'USAGE'
Usage: helium/prepare-source-build.sh /path/to/helium-linux

Install the dotfiles-only Helium vertical-tab patch into an upstream
imputnet/helium-linux checkout. The checkout remains responsible for fetching
Chromium and building it with its normal Docker workflow.
USAGE
}

checkout="${1:-}"
if [[ -z "$checkout" || "$checkout" == "-h" || "$checkout" == "--help" ]]; then
  usage
  [[ -n "$checkout" ]] && exit 0
  exit 2
fi
checkout="$(realpath -m "$checkout")"
series="$checkout/patches/series"
target="$checkout/patches/$PATCH_REL"

if [[ ! -f "$series" || ! -d "$checkout/helium-chromium" ]]; then
  echo "Not an initialized imputnet/helium-linux checkout: $checkout" >&2
  echo "Clone it with --recurse-submodules first." >&2
  exit 1
fi

mkdir -p "$(dirname "$target")"
if [[ -e "$target" ]] && ! cmp -s "$PATCH" "$target"; then
  echo "Refusing to overwrite a different patch: $target" >&2
  exit 1
fi
cp "$PATCH" "$target"

if ! grep -Fqx "$PATCH_REL" "$series"; then
  printf '\n%s\n' "$PATCH_REL" >>"$series"
fi

if command -v git >/dev/null 2>&1; then
  git -C "$checkout" diff --check -- patches/series "$target"
fi

printf 'Helium patch staged: %s\n' "$target"
printf 'Build with: cd %q && scripts/docker-build.sh -c\n' "$checkout"
