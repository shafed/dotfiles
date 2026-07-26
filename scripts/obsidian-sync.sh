#!/usr/bin/env bash
# Shared git sync for the Obsidian vault (~/obsidian). Single source of truth
# for the pull-on-session-entry (kitty/sessions/*.kitty-session,
# daily-notes.sh) and push-on-exit (nvim/lua/utils/obsidian.lua) call sites,
# which used to each inline their own `git pull`/`git push` command.
set -euo pipefail

# OBSIDIAN_VAULT is an override for testing against a throwaway repo; normal
# use leaves it unset. The pull marker is keyed to the vault path so a test
# run can't make the real vault skip its next pull.
vault_path="${OBSIDIAN_VAULT:-$HOME/obsidian}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/obsidian-sync"
mkdir -p "$cache_dir"
last_pull_marker="$cache_dir/last-pull$(printf '%s' "$vault_path" | md5sum | cut -c1-8)"

# The vault syncs across multiple devices, so pull-on-entry matters, but
# opening several kitty sessions back to back (e.g. todos -> obsidian) would
# otherwise pull the same remote state repeatedly within seconds.
pull_throttle_secs=30

# Both commands can run unattended -- pull from a session file that is about to
# hand the terminal to nvim, push detached in the background from nvim -- so a
# message on stdout alone is easy to never see. Callers do their own `return 1`;
# this always succeeds so it can't trip `set -e` on its own (notify-send may be
# missing, and a failed notification must not mask the error being reported).
warn() {
  echo "obsidian-sync: $1" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Obsidian sync" "$1" || true
  fi
}

# Unmerged index entries: the vault is mid-conflict and must not be synced
# further in either direction until a human resolves it.
has_conflicts() {
  [[ -n "$(git -C "$vault_path" ls-files --unmerged)" ]]
}

cmd_pull() {
  if [[ -f "$last_pull_marker" ]]; then
    local age=$(($(date +%s) - $(stat -c %Y "$last_pull_marker")))
    if ((age < pull_throttle_secs)); then
      echo "obsidian-sync: skipping pull, last one was ${age}s ago"
      return 0
    fi
  fi

  if ! git -C "$vault_path" pull --rebase --autostash; then
    warn "pull failed -- resolve manually before editing"
    return 1
  fi

  # A zero exit is not enough. --autostash reapplies the stashed working-tree
  # changes *after* a successful rebase, and when that reapply conflicts (same
  # note edited here and on another device) git still exits 0, having written
  # conflict markers into the notes. Left unchecked, the session would open
  # nvim on a conflicted vault and the next push would commit the markers.
  if has_conflicts; then
    warn "pull left merge conflicts in the vault -- resolve them before editing"
    return 1
  fi

  touch "$last_pull_marker"
}

cmd_push() {
  local silent="${1:-}"
  cd "$vault_path"

  # `git add -A` would happily stage files full of conflict markers and ship
  # them to every other device, so refuse to touch a conflicted vault.
  if has_conflicts; then
    warn "vault has unresolved merge conflicts -- not committing or pushing"
    return 1
  fi

  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Vault backup: $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
  fi

  if ! git push; then
    warn "push failed -- vault not synced to remote"
    return 1
  fi
  [[ "$silent" == "silent" ]] || echo "obsidian-sync: pushed"
}

case "${1:-}" in
pull) cmd_pull ;;
push) cmd_push "${2:-}" ;;
*)
  echo "usage: $(basename "$0") {pull|push} [silent]" >&2
  exit 1
  ;;
esac
