#!/usr/bin/env bash
# PreToolUse hook: refuse `git commit` when the message carries an attribution
# footer — `Co-Authored-By`, a "generated with" line, or the 🤖 marker.
#
# The ban is stated in ~/.claude/CLAUDE.md and again in the /commit skill's
# message rules, but prose only holds as long as it stays in attention. This
# makes it a hard gate.
#
# Costs no context tokens unless it actually fires.

set -euo pipefail

input="$(cat)"

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -n "$cmd" ] || exit 0

# Only guard an actual commit invocation: `git commit` must open a command
# segment (start of line, or after && || ; |). A command that merely mentions
# the words — `git log --grep=...`, a test, a script that echoes them — is not
# a commit and must pass.
if ! printf '%s' "$cmd" | grep -qE '(^|[;&|]|&&|\|\|)[[:space:]]*git[[:space:]]+([^[:space:]]+[[:space:]]+)*commit([[:space:]]|$)'; then
  exit 0
fi

# Require the footer's real shape — `Co-Authored-By:` with the colon, the 🤖
# marker, or a "generated with … claude" line. Without the colon a subject
# like `wiki: document the Co-Authored-By ban` would block its own commit.
if printf '%s' "$cmd" | grep -qiE 'co-authored-by:|🤖|generated with[^"]*claude'; then
  reason="Commit blocked: the message carries an attribution footer (Co-Authored-By / \"generated with\" / 🤖). This repo bans those — see CLAUDE.md. Rewrite the message with the subject alone and retry."
  jq -n --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi

exit 0
