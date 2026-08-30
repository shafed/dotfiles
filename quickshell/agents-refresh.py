#!/usr/bin/env python3
"""Refresh Claude/Codex account limits for the Quickshell AI panel."""

from __future__ import annotations

import json
import os
import re
import select
import shutil
import subprocess
import time
import urllib.request
from pathlib import Path

HOME = Path.home()
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "dots-shell"


def cmd(name):
    return shutil.which(name)


def cached_agents():
    path = CACHE_DIR / "agents.json"
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


def rpc_request(process, request_id, method, params=None, timeout=5):
    process.stdin.write(json.dumps({"id": request_id, "method": method, "params": params or {}}) + "\n")
    process.stdin.flush()
    deadline = time.time() + timeout
    while time.time() < deadline:
        ready, _, _ = select.select([process.stdout], [], [], 0.25)
        if not ready:
            continue
        line = process.stdout.readline()
        if not line:
            break
        try:
            message = json.loads(line)
        except Exception:
            continue
        if message.get("id") == request_id:
            return message
    raise TimeoutError(method)


def codex_limits():
    result = {"plan": "", "limits": []}
    binary = cmd("codex")
    if not binary:
        return result
    try:
        process = subprocess.Popen(
            [binary, "-s", "read-only", "-a", "on-request", "app-server"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            env=os.environ.copy(),
        )
    except Exception:
        return result
    try:
        rpc_request(process, 1, "initialize", {"clientInfo": {"name": "dots-shell", "version": "1"}}, timeout=6)
        process.stdin.write(json.dumps({"method": "initialized", "params": {}}) + "\n")
        process.stdin.flush()
        account_message = rpc_request(process, 2, "account/read", timeout=4)
        limits_message = rpc_request(process, 3, "account/rateLimits/read", timeout=4)
        account = (account_message.get("result") or {}).get("account") or {}
        limits = (limits_message.get("result") or {}).get("rateLimits") or {}
        result["plan"] = str(limits.get("planType") or account.get("planType") or account.get("type") or "")
        for window in (limits.get("primary"), limits.get("secondary")):
            if not isinstance(window, dict) or window.get("usedPercent") is None:
                continue
            minutes = int(window.get("windowDurationMins") or 0)
            label = "7d" if minutes == 10080 else (f"{minutes // 60}h" if minutes and minutes % 60 == 0 else "limit")
            result["limits"].append({
                "label": label,
                "percent": max(0.0, min(1.0, float(window.get("usedPercent")) / 100.0)),
                "resetsAt": str(window.get("resetsAt") or ""),
            })
    except Exception:
        pass
    finally:
        try:
            process.terminate()
            process.wait(timeout=1)
        except Exception:
            try:
                process.kill()
            except Exception:
                pass
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
    claude_installed = cmd("claude") is not None
    if claude_installed or claude.get("limits") or "claude" in previous:
        rows.append(row("claude", "Claude Code", claude_installed, claude, previous.get("claude", {})))

    codex = codex_limits()
    codex_installed = cmd("codex") is not None
    if codex_installed or codex.get("limits") or "codex" in previous:
        rows.append(row("codex", "Codex", codex_installed, codex, previous.get("codex", {})))

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = CACHE_DIR / "agents.json"
    tmp = cache_path.with_suffix(".tmp")
    tmp.write_text(json.dumps(rows, ensure_ascii=False))
    tmp.replace(cache_path)
    print(json.dumps(rows, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
