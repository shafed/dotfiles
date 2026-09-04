#!/usr/bin/env bash
set -euo pipefail

if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "ERROR: not inside a git repository" >&2
  exit 2
fi
cd "$root"

branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED')
head_sha=$(git rev-parse --short=12 HEAD)
repo=$(basename "$root")

printf 'PROJECT\n'
printf 'repo: %s\n' "$repo"
printf 'root: %s\n' "$root"
printf 'branch: %s\n' "$branch"
printf 'head: %s\n' "$head_sha"

if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
  counts=$(git rev-list --left-right --count "$upstream"...HEAD)
  behind=$(printf '%s' "$counts" | awk '{print $1}')
  ahead=$(printf '%s' "$counts" | awk '{print $2}')
  printf 'upstream: %s\n' "$upstream"
  printf 'ahead: %s\nbehind: %s\n' "$ahead" "$behind"
else
  printf 'upstream: none\n'
fi

printf '\nWORKTREE\n'
status=$(git status --porcelain=v1 -uall)
if [ -z "$status" ]; then
  printf 'clean: yes\n'
else
  count=$(printf '%s\n' "$status" | wc -l | tr -d ' ')
  printf 'clean: no\nchanged_count: %s\n' "$count"
  printf '%s\n' "$status" | sed -n '1,40p'
  if [ "$count" -gt 40 ]; then
    printf '... %s more paths omitted\n' "$((count - 40))"
  fi
fi

printf '\nPROJECT_FILES\n'
state_doc=''
for path in CLAUDE.md AGENTS.md README.md docs/STATUS.md STATUS.md TODO.md docs/MIGRATION_PLAN.md docs/SPEC.md docs/ARCHITECTURE.md; do
  if [ -f "$path" ]; then
    printf '%s\n' "$path"
    if [ -z "$state_doc" ] && { [ "$path" = 'docs/STATUS.md' ] || [ "$path" = 'STATUS.md' ] || [ "$path" = 'TODO.md' ]; }; then
      state_doc=$path
    fi
  fi
done

printf '\nRECENT_COMMITS\n'
git log -5 --date=short --format='%h %ad %s'

if [ -n "$state_doc" ]; then
  printf '\nSTATE\nstate_file: %s\n' "$state_doc"
  state_commit=$(git log -1 --format='%H' -- "$state_doc" || true)
  if [ -n "$state_commit" ]; then
    printf 'state_last_commit: %s\n' "$(git rev-parse --short=12 "$state_commit")"
    if [ "$state_commit" != "$(git rev-parse HEAD)" ] && git merge-base --is-ancestor "$state_commit" HEAD 2>/dev/null; then
      commits_after=$(git rev-list --count "$state_commit"..HEAD)
      printf 'commits_after_state: %s\n' "$commits_after"
      printf 'commits_after_state_top:\n'
      git log --format='  %h %s' "$state_commit"..HEAD | sed -n '1,10p'
      printf 'paths_changed_after_state_top:\n'
      git diff --name-only "$state_commit"..HEAD | sed -n '1,40p' | sed 's/^/  /'
    else
      printf 'commits_after_state: 0_or_non_ancestor\n'
    fi
  else
    printf 'state_last_commit: untracked_or_unknown\n'
  fi
else
  printf '\nSTATE\nstate_file: none\n'
fi
