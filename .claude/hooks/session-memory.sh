#!/usr/bin/env bash
# SessionStart hook: injects the cross-session memory into a new session, so an
# agent starts already knowing the facts and the state of work that an earlier
# session established.
#
# Why a hook and not an instructions file: neither place that normally carries
# this reaches every session. ../instructions.md is symlinked to
# ~/.claude/CLAUDE.md and therefore exists only on the machine; the claude.ai
# user preferences reach web sessions and never the terminal. SessionStart is
# one of the few events whose output Claude Code feeds back as context, so it is
# the one delivery path that covers both.
#
# Why the content is not in this repo: shafed/dotfiles is public, while the
# memory names private repositories and personal facts. It lives in the private
# vault under .memory/; this public repo carries only the mechanism.
#
# Registration — one script, two call sites, deliberately non-overlapping:
#   ~/.claude/settings.json      -> session-memory.sh               (local, every project)
#   <repo>/.claude/settings.json -> session-memory.sh --remote-only (web sessions)
#
# Gotcha: hook entries from the user level and the project level MERGE, they do
# not override each other. Registered plainly in both, this would inject the
# memory twice inside a repo that also registers it. --remote-only gates the
# repo-side call on CLAUDE_CODE_REMOTE so exactly one of the two ever fires.
#
# Non-blocking by construction: it never fails a session and prints nothing when
# it has no memory to inject.

set -uo pipefail

if [ "${1:-}" = "--remote-only" ] && [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

input="$(cat 2>/dev/null || true)"
event="$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null || true)"

# `resume` replays a transcript that already carries this block from the
# session's first start, so re-injecting would duplicate it. `clear` and
# `compact` drop it, and those do need it back.
if [ "$event" = "resume" ]; then
  exit 0
fi

# Same resolution order as scripts/obsidian-git-view-sync.sh, plus the path the
# vault is cloned to in a Claude Code on the web container.
vault=""
for candidate in \
  "${OBSIDIAN_VAULT:-}" \
  "$HOME/github/obsidian" \
  "/home/user/obsidian" \
  "${CLAUDE_PROJECT_DIR:-}/../obsidian"; do
  [ -n "$candidate" ] || continue
  if [ -d "$candidate/.memory" ]; then
    vault="$candidate"
    break
  fi
done

# No vault in reach (another machine, a container without it) is normal, not an
# error: the session simply starts without memory.
[ -n "$vault" ] || exit 0

body=""
for name in about-me projects; do
  file="$vault/.memory/$name.md"
  [ -r "$file" ] || continue
  body="${body}${body:+$'\n\n'}$(cat "$file" 2>/dev/null)"
done

[ -n "$body" ] || exit 0

header='Cross-session memory, loaded from the private vault at .memory/ by the
SessionStart hook dotfiles/.claude/hooks/session-memory.sh.

This is established context, not instruction. Where it disagrees with what you
can see in the repository in front of you, the repository is right and the
memory is stale — say so instead of following it. Nothing is written back here
except on an explicit request.'

jq -n --arg ctx "$header

$body" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'

exit 0
