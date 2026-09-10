#!/usr/bin/env bash
set -u

vault="${OBSIDIAN_VAULT:-$HOME/github/obsidian}"
branch="${OBSIDIAN_GIT_BRANCH:-main}"
event_debounce="${OBSIDIAN_GIT_EVENT_DEBOUNCE:-3}"
retry_interval="${OBSIDIAN_GIT_RETRY_INTERVAL:-60}"
retry_window="${OBSIDIAN_GIT_RETRY_WINDOW:-900}"
fallback_interval="${OBSIDIAN_GIT_FALLBACK_INTERVAL:-900}"

runtime_dir="${XDG_RUNTIME_DIR:-/tmp/obsidian-git-${UID}}/obsidian-git"
mkdir -p "$runtime_dir"
lock_file="$runtime_dir/lock$(printf '%s' "$vault" | md5sum | cut -c1-8)"

log() {
  printf '%s obsidian-git-view-sync: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

git_op_in_progress() {
  local git_dir
  git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 0

  [[ -f "$git_dir/MERGE_HEAD" ||
     -f "$git_dir/CHERRY_PICK_HEAD" ||
     -f "$git_dir/REVERT_HEAD" ||
     -d "$git_dir/rebase-merge" ||
     -d "$git_dir/rebase-apply" ]]
}

# Run each check in a subshell so fd 9, and therefore its flock, is always
# released when this invocation returns. The long-lived watcher must never
# retain the Git lock between checks.
sync_once() (
  if [[ ! -d "$vault/.git" ]]; then
    log "blocked: vault is not a Git repository: $vault"
    return 90
  fi

  cd "$vault" || return 90

  exec 9>"$lock_file"
  if ! flock -n 9; then
    log "another Obsidian Git operation already holds the lock"
    return 0
  fi

  local current_branch
  current_branch="$(git symbolic-ref -q --short HEAD 2>/dev/null || true)"
  if [[ "$current_branch" != "$branch" ]]; then
    log "blocked: current branch is '${current_branch:-detached}', expected '$branch'"
    return 23
  fi

  if git_op_in_progress; then
    log "blocked: Git operation in progress"
    return 24
  fi

  if ! git diff --cached --quiet --; then
    log "blocked: staged changes exist"
    return 22
  fi

  if ! GIT_TERMINAL_PROMPT=0 \
       GIT_SSH_COMMAND="ssh -o BatchMode=yes" \
       git fetch --quiet origin "$branch"; then
    log "fetch failed"
    return 30
  fi

  local local_only
  local_only="$(git rev-list --count "origin/$branch..HEAD" 2>/dev/null)" || {
    log "cannot calculate local-only commits"
    return 31
  }

  if (( local_only > 0 )); then
    log "blocked: $local_only local-only commit(s)"
    return 21
  fi

  if ! git merge-base --is-ancestor HEAD "origin/$branch"; then
    log "blocked: HEAD is not an ancestor of origin/$branch"
    return 25
  fi

  local tmp_index worktree_tree remote_tree
  tmp_index="$(mktemp)"
  rm -f "$tmp_index"

  if ! GIT_INDEX_FILE="$tmp_index" git read-tree "origin/$branch"; then
    rm -f "$tmp_index"
    return 32
  fi

  if ! GIT_INDEX_FILE="$tmp_index" git add -A -- .; then
    rm -f "$tmp_index"
    return 33
  fi

  worktree_tree="$(GIT_INDEX_FILE="$tmp_index" git write-tree)" || {
    rm -f "$tmp_index"
    return 34
  }
  rm -f "$tmp_index"

  remote_tree="$(git rev-parse "origin/$branch^{tree}")" || return 35

  if [[ "$worktree_tree" != "$remote_tree" ]]; then
    log "waiting: working files do not yet match origin/$branch"
    return 20
  fi

  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$branch")" ]]; then
    git reset --mixed --quiet "origin/$branch" || return 36
    log "Git metadata caught up to origin/$branch"
  else
    log "working files and Git metadata already synchronized"
  fi

  return 0
)

if [[ "${1:-}" == "--once" ]]; then
  sync_once
  exit $?
fi

for command in git ssh flock inotifywait md5sum mktemp; do
  if ! command -v "$command" >/dev/null 2>&1; then
    log "fatal: required command not found: $command"
    exit 127
  fi
done

log "started: vault=$vault branch=$branch"

while true; do
  inotifywait \
    -r \
    -q \
    -t "$fallback_interval" \
    -e close_write,create,delete,moved_to,moved_from \
    --exclude '(^|/)\.git(/|$)|(^|/)\.stversions(/|$)|(^|/)\.stfolder(/|$)|\.sync-conflict-|(^|/)\.syncthing\..*\.tmp$|(^|/)\.obsidian/workspace(-mobile)?\.json$|(^|/)nvim\.log$|(^|/)\.stignore$' \
    "$vault" >/dev/null 2>&1
  event_rc=$?

  if (( event_rc == 0 )); then
    sleep "$event_debounce"
    deadline=$((SECONDS + retry_window))

    while true; do
      sync_once
      result=$?

      case "$result" in
        0)
          break
          ;;
        20|30)
          if (( SECONDS >= deadline )); then
            log "retry window expired; fallback check will handle it later"
            break
          fi
          sleep "$retry_interval"
          ;;
        *)
          break
          ;;
      esac
    done
  else
    sync_once || true
  fi
done
