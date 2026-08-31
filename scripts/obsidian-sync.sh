#!/usr/bin/env bash
# Shared git sync for the Obsidian vault (~/github/obsidian). Single source of truth
# for the pull-on-session-entry (kitty/sessions/*.kitty-session,
# daily-notes.sh) and push-on-exit (nvim/lua/utils/obsidian.lua) call sites,
# which used to each inline their own `git pull`/`git push` command.
set -euo pipefail

# OBSIDIAN_VAULT is an override for testing against a throwaway repo; normal
# use leaves it unset. The lock is keyed to the vault path so test and real
# repositories do not block each other.
vault_path="${OBSIDIAN_VAULT:-$HOME/github/obsidian}"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/obsidian-sync"
mkdir -p "$cache_dir"
lock_file="$cache_dir/lock$(printf '%s' "$vault_path" | md5sum | cut -c1-8)"

# Both commands can run unattended -- pull from a session file that is about to
# hand the terminal to nvim, push detached in the background from nvim -- so a
# message on stdout alone is easy to never see. Callers do their own `return 1`;
# this always succeeds so it can't trip `set -e` on its own (notify-send may be
# missing, and a failed notification must not mask the error being reported).
warn() {
  echo "obsidian-sync: $1" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical -t 3000 "Obsidian sync" "$1" || true
  fi
}

# Unmerged index entries: the vault is mid-conflict and must not be synced
# further in either direction until a human resolves it.
has_conflicts() {
  [[ -n "$(git -C "$vault_path" ls-files --unmerged)" ]]
}

# A merge/rebase can still be in progress even after a user has staged files.
# Refuse to turn that intermediate state into a normal vault-backup commit.
has_operation_in_progress() {
  local git_dir
  if ! git_dir="$(git -C "$vault_path" rev-parse --absolute-git-dir 2>/dev/null)"; then
    return 0
  fi
  [[ -f "$git_dir/MERGE_HEAD" ||
    -f "$git_dir/CHERRY_PICK_HEAD" ||
    -f "$git_dir/REVERT_HEAD" ||
    -d "$git_dir/rebase-merge" ||
    -d "$git_dir/rebase-apply" ]]
}

# Git can consider the index resolved while literal conflict markers have been
# saved into a Markdown note. That happened in the phone/Termux history once,
# turning both sides of a conflict into ordinary note content. Never publish it.
has_conflict_markers() {
  git -C "$vault_path" grep -I -n -E '^(<<<<<<< .+|>>>>>>> .+)$' -- '*.md' \
    >/dev/null 2>&1
}

preflight_merge_state() {
  if has_operation_in_progress; then
    warn "git merge/rebase is still in progress -- resolve or abort it before syncing"
    return 1
  fi
  if has_conflicts; then
    warn "vault has unresolved merge conflicts -- resolve them before syncing"
    return 1
  fi
  if has_conflict_markers; then
    warn "vault contains Git conflict markers in Markdown -- not syncing them"
    return 1
  fi
}

acquire_lock() {
  exec 9>"$lock_file"
  if ! flock 9; then
    warn "could not acquire sync lock"
    return 1
  fi
}

cmd_pull() {
  if ! preflight_merge_state; then
    return 1
  fi

  if ! git -C "$vault_path" pull --rebase --autostash; then
    warn "pull failed -- resolve manually before editing"
    return 1
  fi

  # A zero exit is not enough. --autostash reapplies the stashed working-tree
  # changes *after* a successful rebase, and when that reapply conflicts (same
  # note edited here and on another device) Git can leave conflict material in
  # the worktree. Left unchecked, the next push could publish it as note text.
  if has_conflicts || has_operation_in_progress; then
    warn "pull left merge conflicts in the vault -- resolve them before editing"
    return 1
  fi
  if has_conflict_markers; then
    warn "pull left Git conflict markers in Markdown -- resolve them before editing"
    return 1
  fi
}

cmd_push() {
  local silent="${1:-}"
  local diff_status
  cd "$vault_path"

  if ! preflight_merge_state; then
    return 1
  fi

  # Synchronize the remote state before taking a local snapshot. This matters
  # for edits inside a note too: if another device removed old lines while this
  # device still has a stale copy open, the remote deletion lands first and the
  # local working-tree diff is then reapplied on top. Non-overlapping new edits
  # survive; an actual same-hunk conflict stops instead of resurrecting text.
  if ! cmd_pull; then
    return 1
  fi

  if ! git add -A; then
    warn "could not stage vault changes"
    return 1
  fi

  # Staging must not turn a half-resolved merge or literal marker text into a
  # publishable backup commit.
  if ! preflight_merge_state; then
    return 1
  fi

  if git diff --cached --quiet; then
    diff_status=0
  else
    diff_status=$?
  fi
  if ((diff_status > 1)); then
    warn "could not inspect staged vault changes"
    return 1
  fi
  if ((diff_status == 1)); then
    if ! git commit -m "Vault backup: $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null; then
      warn "could not commit vault changes"
      return 1
    fi
  fi

  if ! git push; then
    warn "push failed -- vault not synced to remote"
    return 1
  fi
  [[ "$silent" == "silent" ]] || echo "obsidian-sync: pushed"
}

case "${1:-}" in
pull)
  acquire_lock
  cmd_pull
  ;;
push)
  acquire_lock
  cmd_push "${2:-}"
  ;;
*)
  echo "usage: $(basename "$0") {pull|push} [silent]" >&2
  exit 1
  ;;
esac
