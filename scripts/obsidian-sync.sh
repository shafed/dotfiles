#!/usr/bin/env bash
set -euo pipefail

vault="${OBSIDIAN_VAULT:-$HOME/github/obsidian}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/obsidian-sync"
mkdir -p "$cache_dir"
lock_file="$cache_dir/lock$(printf '%s' "$vault" | md5sum | cut -c1-8)"

warn() {
  echo "obsidian-sync: $1" >&2
  command -v notify-send >/dev/null 2>&1 && \
    notify-send -u critical -t 3000 "Obsidian sync" "$1" || true
}

pull() {
  if ! git -C "$vault" pull --rebase --autostash; then
    warn "pull failed -- resolve the conflict before syncing"
    return 1
  fi

  # An autostash conflict can remain after pull. Do not stage it.
  if [[ -n "$(git -C "$vault" diff --name-only --diff-filter=U)" ]]; then
    warn "pull left a conflict -- resolve it before syncing"
    return 1
  fi
}

push() {
  local silent="${1:-}"

  pull || return 1
  git -C "$vault" add -A

  if ! git -C "$vault" diff --cached --quiet; then
    git -C "$vault" commit -m "Vault backup: $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
  fi

  if ! git -C "$vault" push; then
    warn "push failed -- vault not synced"
    return 1
  fi

  [[ "$silent" == "silent" ]] || echo "obsidian-sync: pushed"
}

exec 9>"$lock_file"
flock 9

case "${1:-}" in
pull) pull ;;
push) push "${2:-}" ;;
*)
  echo "usage: $(basename "$0") {pull|push} [silent]" >&2
  exit 1
  ;;
esac
