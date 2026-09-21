#!/usr/bin/env python3
"""Register this repo's global Claude Code hooks in ~/.claude/settings.json.

Claude Code owns settings.json as live, mutable state: it writes the file
itself the first time a /config option that belongs in user settings changes,
such as the theme. So ~/.claude/settings.json is intentionally not a tracked
symlink, for the same reason ~/.config/copyq is not (see
scripts/copyq-apply-theme.py) — the application would either clobber the link
or turn every apply into permanent drift.

This merges only the hook entries this repo owns and leaves everything else in
the file untouched: theme, model, permission rules, statusLine, whatever else
Claude Code or the user put there.

Ownership is decided by the script a hook calls, not by the exact command
string, so a hand-written registration pointing at the same script through a
different path is replaced rather than duplicated.

Run by `dots apply` as the `claude-user-hooks` generator. `dots plan` executes
it twice against a copy and rejects it if the two runs differ, so the output
has to be deterministic: dict order is insertion order here, and nothing
timestamped or randomized goes into the file.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

SETTINGS = Path.home() / ".claude/settings.json"

# event -> (matcher or None, command). The command is written with $HOME rather
# than an expanded path so the file stays identical on every machine.
MANAGED: list[tuple[str, str | None, str, str]] = [
    (
        "SessionStart",
        None,
        '"$HOME/.claude/hooks/session-memory.sh"',
        "load cross-session memory",
    ),
    (
        "PreToolUse",
        "Bash",
        '"$HOME/.claude/hooks/no-coauthor.sh"',
        "attribution footer guard",
    ),
]

OWNED_SCRIPTS = {"session-memory.sh", "no-coauthor.sh"}


def owned(command: str) -> bool:
    """True when a command invokes one of the scripts this generator manages."""
    return any(name in command for name in OWNED_SCRIPTS)


def strip_owned(settings: dict) -> None:
    """Drop every existing registration of a script we own, at any path."""
    hooks = settings.get("hooks")
    if not isinstance(hooks, dict):
        return
    for event, entries in list(hooks.items()):
        if not isinstance(entries, list):
            continue
        kept_entries = []
        for entry in entries:
            if not isinstance(entry, dict):
                kept_entries.append(entry)
                continue
            inner = entry.get("hooks")
            if not isinstance(inner, list):
                kept_entries.append(entry)
                continue
            kept_inner = [
                hook
                for hook in inner
                if not (isinstance(hook, dict) and owned(str(hook.get("command", ""))))
            ]
            if not kept_inner:
                # The whole entry existed only for a hook we own: drop it, so a
                # stale matcher does not survive as an empty group.
                continue
            entry["hooks"] = kept_inner
            kept_entries.append(entry)
        if kept_entries:
            hooks[event] = kept_entries
        else:
            del hooks[event]
    if not hooks:
        settings.pop("hooks", None)


def add_managed(settings: dict) -> None:
    hooks = settings.setdefault("hooks", {})
    for event, matcher, command, status in MANAGED:
        entries = hooks.setdefault(event, [])
        hook = {"type": "command", "command": command, "statusMessage": status}
        # Reuse an existing group with the same matcher so unrelated hooks on
        # the same event keep their grouping instead of being split apart.
        for entry in entries:
            if isinstance(entry, dict) and entry.get("matcher") == matcher:
                entry.setdefault("hooks", []).append(hook)
                break
        else:
            entry = {"hooks": [hook]} if matcher is None else {"matcher": matcher, "hooks": [hook]}
            entries.append(entry)


def main() -> int:
    if SETTINGS.exists():
        try:
            settings = json.loads(SETTINGS.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            print(f"{SETTINGS} is not valid JSON ({error}); refusing to rewrite it", file=sys.stderr)
            return 1
        if not isinstance(settings, dict):
            print(f"{SETTINGS} is not a JSON object; refusing to rewrite it", file=sys.stderr)
            return 1
    else:
        settings = {}

    strip_owned(settings)
    add_managed(settings)

    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
