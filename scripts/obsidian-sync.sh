#!/usr/bin/env bash
# Shared git sync for the Obsidian vault (~/obsidian). Single source of truth
# for the pull-on-session-entry (kitty/sessions/*.kitty-session,
# daily-notes.sh) and push-on-exit (nvim/lua/utils/obsidian.lua) call sites,
# which used to each inline their own `git pull`/`git push` command.
set -euo pipefail

vault_path="$HOME/obsidian"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/obsidian-sync"
mkdir -p "$cache_dir"
last_pull_marker="$cache_dir/last-pull"

# The vault syncs across multiple devices, so pull-on-entry matters, but
# opening several kitty sessions back to back (e.g. todos -> obsidian) would
# otherwise pull the same remote state repeatedly within seconds.
pull_throttle_secs=30

cmd_pull() {
  if [[ -f "$last_pull_marker" ]]; then
    local age=$(($(date +%s) - $(stat -c %Y "$last_pull_marker")))
    if ((age < pull_throttle_secs)); then
      echo "obsidian-sync: skipping pull, last one was ${age}s ago"
      return 0
    fi
  fi

  if git -C "$vault_path" pull --rebase --autostash; then
    touch "$last_pull_marker"
  else
    echo "obsidian-sync: pull failed -- resolve manually before editing" >&2
    return 1
  fi
}

cmd_push() {
  local silent="${1:-}"
  cd "$vault_path"
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Vault backup: $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
  fi

  if git push; then
    [[ "$silent" == "silent" ]] || echo "obsidian-sync: pushed"
  else
    echo "obsidian-sync: push failed" >&2
    return 1
  fi
}

case "${1:-}" in
pull) cmd_pull ;;
push) cmd_push "${2:-}" ;;
*)
  echo "usage: $(basename "$0") {pull|push} [silent]" >&2
  exit 1
  ;;
esac
