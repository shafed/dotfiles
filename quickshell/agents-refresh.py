#!/usr/bin/env python3
"""Refresh Claude/Codex account limits without rescanning local token history."""

from __future__ import annotations

import json
import os
from pathlib import Path

import backend


def cached_agents():
    path = backend.CACHE_DIR / "agents.json"
    try:
        rows = json.loads(path.read_text())
        if isinstance(rows, list):
            return {str(row.get("id") or ""): row for row in rows if isinstance(row, dict)}
    except Exception:
        pass
    return {}


def row(agent_id, name, installed, fresh, previous):
    fresh_limits = fresh.get("limits") if isinstance(fresh, dict) else None
    old_limits = previous.get("limits") if isinstance(previous, dict) else None
    limits = fresh_limits if fresh_limits else (old_limits or [])
    plan = str((fresh.get("plan") if isinstance(fresh, dict) else "") or previous.get("plan") or "")
    return {
        "id": agent_id,
        "name": name,
        "installed": bool(installed),
        "plan": plan,
        "limits": limits,
        "today": 0,
        "week": 0,
        "prompts": 0,
        "sessions": 0,
        "days": [],
        "models": [],
    }


def main():
    previous = cached_agents()
    rows = []

    claude_root = Path(os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")))
    claude = backend.claude_limits(claude_root)
    claude_installed = backend.cmd("claude") is not None
    if claude_installed or claude.get("limits") or "claude" in previous:
        rows.append(row("claude", "Claude Code", claude_installed, claude, previous.get("claude", {})))

    codex = backend.codex_limits()
    codex_installed = backend.cmd("codex") is not None
    if codex_installed or codex.get("limits") or "codex" in previous:
        rows.append(row("codex", "Codex", codex_installed, codex, previous.get("codex", {})))

    backend.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = backend.CACHE_DIR / "agents.json"
    tmp = cache_path.with_suffix(".tmp")
    tmp.write_text(json.dumps(rows, ensure_ascii=False))
    tmp.replace(cache_path)
    print(json.dumps(rows, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
