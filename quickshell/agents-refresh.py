#!/usr/bin/env python3
"""Refresh Claude/Codex account limits without rescanning local token history."""

from __future__ import annotations

import json
import os
import re
import urllib.request
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


def claude_limits(root):
    """Read the same two account windows shown on Claude's Usage page."""
    result = {"plan": "", "limits": []}
    try:
        login = json.loads((root / ".credentials.json").read_text()).get("claudeAiOauth") or {}
    except Exception:
        return result

    tier = str(login.get("rateLimitTier") or "")
    subscription = str(login.get("subscriptionType") or "")
    match = re.search(r"max_(\d+x)", tier, re.I)
    result["plan"] = "Max " + match.group(1) if match else (
        subscription[:1].upper() + subscription[1:] if subscription else ""
    )

    token = str(login.get("accessToken") or "")
    if not token:
        return result

    request = urllib.request.Request(
        "https://api.anthropic.com/api/oauth/usage",
        headers={
            "Authorization": "Bearer " + token,
            "anthropic-beta": "oauth-2025-04-20",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=7) as response:
            payload = json.loads(response.read().decode("utf-8", errors="replace"))
    except Exception:
        return result

    # Claude's web Usage page labels these as Current session and Weekly limits.
    # `seven_day` is the All models weekly bucket. `seven_day_oauth_apps` is a
    # narrower OAuth-app bucket and can disagree substantially with the website.
    buckets = [
        ("5h", payload.get("five_hour")),
        ("7d", payload.get("seven_day") or payload.get("seven_day_oauth_apps")),
    ]
    raw_values = [bucket.get("utilization") for _, bucket in buckets if isinstance(bucket, dict)]
    try:
        percent_scaled = any(float(value or 0) >= 1 for value in raw_values)
    except Exception:
        percent_scaled = True

    for label, bucket in buckets:
        if not isinstance(bucket, dict) or bucket.get("utilization") is None:
            continue
        try:
            value = float(bucket.get("utilization"))
        except Exception:
            continue
        percent = value / 100.0 if percent_scaled or value > 1 else value
        result["limits"].append({
            "label": label,
            "percent": max(0.0, min(1.0, percent)),
            "resetsAt": str(bucket.get("resets_at") or ""),
        })
    return result


def row(agent_id, name, installed, fresh, previous):
    fresh_limits = fresh.get("limits") if isinstance(fresh, dict) else None
    old_limits = previous.get("limits") if isinstance(previous, dict) else None
    stale = not bool(fresh_limits) and bool(old_limits)
    limits = fresh_limits if fresh_limits else (old_limits or [])
    plan = str((fresh.get("plan") if isinstance(fresh, dict) else "") or previous.get("plan") or "")
    return {
        "id": agent_id,
        "name": name,
        "installed": bool(installed),
        "plan": plan,
        "limits": limits,
        "stale": stale,
    }


def main():
    previous = cached_agents()
    rows = []

    claude_root = Path(os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")))
    claude = claude_limits(claude_root)
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
