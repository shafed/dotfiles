#!/usr/bin/env bash
# PreToolUse hook: refuse `git commit` when the message carries an attribution
# footer — `Co-Authored-By`, a "generated with" line, or the 🤖 marker.
#
# The ban is stated in ~/.claude/CLAUDE.md and again in the /commit skill's
# message rules, but prose only holds as long as it stays in attention. This
# makes it a hard gate.
#
# Only the commit message is checked — every -m/--message value (subject and
# body) and the file behind -F/--file. The rest of the command is not: a
# `git commit … && git log | rg '🤖'` in the same Bash call used to be blocked
# for the rg pattern alone. If the command cannot be parsed, or the message
# comes from stdin (`-F -`), the whole command is checked instead, so an
# unparseable commit fails closed rather than slipping through.
#
# Costs no context tokens unless it actually fires.

set -euo pipefail

input="$(cat)"

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -n "$cmd" ] || exit 0
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"

# Prints the text to check: the messages of every `git commit` in the command,
# nothing when there is no commit, or the whole command when parsing fails.
text="$(CMD="$cmd" CWD="${cwd:-$PWD}" python3 - <<'PY'
import os, shlex, sys

cmd = os.environ["CMD"]
cwd = os.environ["CWD"]

def whole():
    sys.stdout.write(cmd)
    sys.exit(0)

try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=";&|\n")
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    tokens = list(lex)
except ValueError:
    whole()

# Split into simple commands on ; && || | and newlines.
segments, cur = [], []
for tok in tokens:
    if tok and set(tok) <= set(";&|\n"):
        segments.append(cur)
        cur = []
    else:
        cur.append(tok)
segments.append(cur)

parts = []
for seg in segments:
    i = 0
    while i < len(seg) and "=" in seg[i] and not seg[i].startswith("-"):
        i += 1  # VAR=value prefixes
    if i >= len(seg) or os.path.basename(seg[i]) != "git":
        continue
    i += 1
    repo = cwd
    while i < len(seg) and seg[i].startswith("-"):
        if seg[i] in ("-C", "-c", "--git-dir", "--work-tree", "--namespace"):
            if seg[i] == "-C" and i + 1 < len(seg):
                repo = os.path.join(repo, seg[i + 1])
            i += 2
        else:
            i += 1
    if i >= len(seg) or seg[i] != "commit":
        continue
    args = seg[i + 1:]
    j = 0
    while j < len(args):
        a = args[j]
        nxt = args[j + 1] if j + 1 < len(args) else None
        value = kind = None
        if a in ("-m", "--message"):
            kind, value, j = "m", nxt, j + 1
        elif a.startswith("--message="):
            kind, value = "m", a.split("=", 1)[1]
        elif a in ("-F", "--file"):
            kind, value, j = "F", nxt, j + 1
        elif a.startswith("--file="):
            kind, value = "F", a.split("=", 1)[1]
        elif a.startswith("-") and not a.startswith("--") and len(a) > 1:
            # Short-option cluster such as -am "msg" or -amMSG.
            for k, ch in enumerate(a[1:], start=1):
                if ch in "mF":
                    kind = ch
                    rest = a[k + 1:]
                    if rest:
                        value = rest
                    else:
                        value, j = nxt, j + 1
                    break
        j += 1
        if kind is None:
            continue
        if value is None:
            whole()
        if kind == "m":
            parts.append(value)
        elif value == "-":
            whole()
        else:
            path = value if os.path.isabs(value) else os.path.join(repo, value)
            try:
                with open(path, encoding="utf-8", errors="replace") as f:
                    parts.append(f.read())
            except OSError:
                whole()

sys.stdout.write("\n".join(parts))
PY
)" || text="$cmd"

[ -n "$text" ] || exit 0

# Require the footer's real shape — `Co-Authored-By:` with the colon, the 🤖
# marker, or a "generated with … claude" line. Without the colon a subject
# like `wiki: document the Co-Authored-By ban` would block its own commit.
if printf '%s' "$text" | grep -qiE 'co-authored-by:|🤖|generated with[^"]*claude'; then
  reason="Commit blocked: the message carries an attribution footer (Co-Authored-By / \"generated with\" / 🤖). This repo bans those — see CLAUDE.md. Rewrite the message with the subject alone and retry."
  jq -n --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi

exit 0
