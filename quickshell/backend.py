#!/usr/bin/env python3
"""JSON backend for the personal Quickshell desktop shell.

The QML layer only renders state and sends actions. This process owns the
system integrations so the shell has no Omarchy runtime dependency.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import re
import select
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

HOME = Path.home()
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "dots-shell"
STATE_DIR = HOME / ".local/state/dots-shell"
NOTIFICATION_STATE = STATE_DIR / "notifications.json"


def run(args, timeout=5):
    try:
        process = subprocess.run(args, text=True, capture_output=True, timeout=timeout, check=False)
        return process.returncode, process.stdout.strip(), process.stderr.strip()
    except Exception as exc:
        return 127, "", str(exc)


def cmd(name):
    return shutil.which(name)


def emit(data):
    print(json.dumps(data, ensure_ascii=False, separators=(",", ":")))


def cached_json(name, ttl, producer):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / f"{name}.json"
    try:
        if path.exists() and time.time() - path.stat().st_mtime < ttl:
            return json.loads(path.read_text())
    except Exception:
        pass
    value = producer()
    try:
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(value, ensure_ascii=False))
        tmp.replace(path)
    except Exception:
        pass
    return value


# ------------------------------------------------------------------ desktop


def audio():
    data = {"volume": 0, "muted": False, "sinks": [], "streams": []}
    rc, text, _ = run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]) if cmd("wpctl") else (1, "", "")
    if rc == 0:
        match = re.search(r"Volume:\s*([0-9.]+)", text)
        if match:
            data["volume"] = max(0, min(150, round(float(match.group(1)) * 100)))
        data["muted"] = "[MUTED]" in text

    if not cmd("wpctl"):
        return data
    rc, text, _ = run(["wpctl", "status", "-n"])
    if rc:
        return data

    section = ""
    for raw in text.splitlines():
        line = raw.strip()
        if line.endswith("Sinks:"):
            section = "sinks"
            continue
        if line.endswith("Streams:"):
            section = "streams"
            continue
        if line.endswith(":") and not re.match(r"^[*│├└\s]*\d+\.", line):
            section = ""
            continue
        match = re.search(r"(\*)?\s*(\d+)\.\s+(.+?)(?:\s+\[vol:.*)?$", line)
        if not match or section not in ("sinks", "streams"):
            continue
        item = {
            "id": int(match.group(2)),
            "name": match.group(3).strip(),
            "default": bool(match.group(1)),
        }
        if section == "streams":
            rcv, volume_text, _ = run(["wpctl", "get-volume", str(item["id"])])
            volume_match = re.search(r"Volume:\s*([0-9.]+)", volume_text)
            item["volume"] = round(float(volume_match.group(1)) * 100) if rcv == 0 and volume_match else 0
            item["muted"] = "[MUTED]" in volume_text
        data[section].append(item)
    return data


def network():
    data = {"enabled": False, "active": "", "networks": []}
    if not cmd("nmcli"):
        return data
    rc, text, _ = run(["nmcli", "-t", "-f", "WIFI", "general"])
    data["enabled"] = rc == 0 and "enabled" in text.lower()
    rc, text, _ = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if rc == 0:
        for line in text.splitlines():
            if line.endswith(":802-11-wireless") or line.endswith(":wifi"):
                data["active"] = line.rsplit(":", 1)[0].replace("\\:", ":")
                break
    rc, text, _ = run(
        ["nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"],
        timeout=8,
    )
    if rc == 0:
        seen = set()
        for line in text.splitlines():
            parts = re.split(r"(?<!\\):", line, maxsplit=3)
            if len(parts) < 4:
                continue
            active, ssid, signal, security = [part.replace("\\:", ":") for part in parts]
            if not ssid or ssid in seen:
                continue
            seen.add(ssid)
            data["networks"].append({
                "ssid": ssid,
                "active": active == "*",
                "signal": int(signal or 0),
                "security": security,
            })
    return data


def bluetooth():
    data = {"powered": False, "devices": []}
    if not cmd("bluetoothctl"):
        return data
    rc, text, _ = run(["bluetoothctl", "show"])
    data["powered"] = rc == 0 and "Powered: yes" in text
    rc, text, _ = run(["bluetoothctl", "devices", "Paired"])
    if rc:
        rc, text, _ = run(["bluetoothctl", "paired-devices"])
    if rc == 0:
        for line in text.splitlines():
            match = re.match(r"Device\s+([0-9A-Fa-f:]+)\s+(.+)$", line)
            if not match:
                continue
            mac, name = match.groups()
            _, info, _ = run(["bluetoothctl", "info", mac])
            batt = re.search(r"Battery Percentage:\s+\S+\s+\((\d+)\)", info)
            data["devices"].append({
                "mac": mac,
                "name": name,
                "connected": "Connected: yes" in info,
                "battery": int(batt.group(1)) if batt else -1,
            })
    return data


def power():
    data = {"profile": "", "profiles": [], "battery": -1, "status": "", "uptime": ""}
    if cmd("powerprofilesctl"):
        rc, text, _ = run(["powerprofilesctl", "get"])
        if rc == 0:
            data["profile"] = text
        rc, text, _ = run(["powerprofilesctl", "list"])
        if rc == 0:
            data["profiles"] = re.findall(r"(?:\* )?([a-z-]+):", text)
    batteries = list(Path("/sys/class/power_supply").glob("BAT*"))
    if batteries:
        try:
            data["battery"] = int((batteries[0] / "capacity").read_text().strip())
            data["status"] = (batteries[0] / "status").read_text().strip()
        except OSError:
            pass
    rc, text, _ = run(["uptime", "-p"])
    if rc == 0:
        data["uptime"] = text.removeprefix("up ")
    return data


def brightness():
    if not cmd("brightnessctl"):
        return -1
    rc, text, _ = run(["brightnessctl", "-m"])
    if rc:
        return -1
    parts = text.split(",")
    try:
        return int(parts[3].rstrip("%")) if len(parts) >= 4 else -1
    except ValueError:
        return -1


def active_workspace():
    rc, text, _ = run(["hyprctl", "-j", "activeworkspace"])
    if rc == 0:
        try:
            return int(json.loads(text).get("id", 1))
        except Exception:
            pass
    return 1


def keyboard_layout():
    rc, text, _ = run(["hyprctl", "-j", "devices"])
    if rc == 0:
        try:
            for keyboard in json.loads(text).get("keyboards", []):
                if keyboard.get("main"):
                    return str(keyboard.get("active_keymap", ""))
        except Exception:
            pass
    return ""


# ------------------------------------------------------------------- updates


def _updates_uncached():
    count = 0
    if cmd("checkupdates"):
        _, text, _ = run(["checkupdates"], timeout=12)
        count += len([line for line in text.splitlines() if line.strip()])
    for helper in ("yay", "paru"):
        if cmd(helper):
            _, text, _ = run([helper, "-Qua"], timeout=15)
            count += len([line for line in text.splitlines() if line.strip()])
            break
    return {"count": count}


def updates():
    return cached_json("updates", 600, _updates_uncached)


# -------------------------------------------------------------------- agents


def token_total(usage):
    if not isinstance(usage, dict):
        return 0
    for total_key in ("total_tokens", "totalTokens"):
        if isinstance(usage.get(total_key), (int, float)):
            return int(usage[total_key])
    keys = (
        "input_tokens", "output_tokens", "cached_input_tokens",
        "cache_read_input_tokens", "cache_creation_input_tokens",
        "inputTokens", "outputTokens", "cacheReadInputTokens",
        "cacheCreationInputTokens",
    )
    return sum(int(usage.get(key, 0) or 0) for key in keys)


def local_day(stamp):
    try:
        return dt.datetime.fromisoformat(str(stamp).replace("Z", "+00:00")).astimezone().date()
    except Exception:
        return dt.datetime.now().astimezone().date()


def empty_agent(agent_id, name, installed):
    today = dt.datetime.now().astimezone().date()
    days = {str(today - dt.timedelta(days=i)): 0 for i in range(6, -1, -1)}
    return {
        "id": agent_id,
        "name": name,
        "installed": installed,
        "plan": "",
        "limits": [],
        "today": 0,
        "week": 0,
        "prompts": 0,
        "sessions": 0,
        "days": days,
        "models": {},
    }


def finalize_agent(agent):
    days = agent.pop("days")
    models = agent.pop("models")
    agent["today"] = days.get(str(dt.datetime.now().astimezone().date()), 0)
    agent["week"] = sum(days.values())
    agent["days"] = [{"date": key, "tokens": value} for key, value in days.items()]
    agent["models"] = [
        {"name": key, "tokens": value}
        for key, value in sorted(models.items(), key=lambda item: -item[1])[:8]
    ]
    pieces = []
    if agent.get("plan"):
        pieces.append(str(agent["plan"]))
    for limit in agent.get("limits", [])[:2]:
        pieces.append(f"{limit['label']} {round(float(limit['percent']) * 100)}%")
    agent["name"] = agent["name"] + (" · " + " · ".join(pieces) if pieces else "")
    return agent


def claude_limits(root):
    result = {"plan": "", "limits": []}
    try:
        login = json.loads((root / ".credentials.json").read_text()).get("claudeAiOauth") or {}
    except Exception:
        return result
    tier = str(login.get("rateLimitTier") or "")
    subscription = str(login.get("subscriptionType") or "")
    match = re.search(r"max_(\d+x)", tier, re.I)
    result["plan"] = "Max " + match.group(1) if match else (subscription[:1].upper() + subscription[1:] if subscription else "")
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
        ("7d", payload.get("seven_day_oauth_apps") or payload.get("seven_day")),
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


def claude_usage():
    root = Path(os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")))
    agent = empty_agent("claude", "Claude Code", cmd("claude") is not None)
    sessions = set()
    projects = root / "projects"
    files = projects.rglob("*.jsonl") if projects.exists() else []
    for path in files:
        try:
            for line in path.open(errors="ignore"):
                if '"usage"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except Exception:
                    continue
                message = entry.get("message") if isinstance(entry.get("message"), dict) else {}
                usage = message.get("usage") or entry.get("usage")
                total = token_total(usage)
                if total <= 0:
                    continue
                day = local_day(entry.get("timestamp") or message.get("timestamp"))
                model = str(message.get("model") or entry.get("model") or "claude")
                if str(day) in agent["days"]:
                    agent["days"][str(day)] += total
                agent["models"][model] = agent["models"].get(model, 0) + total
                sessions.add(str(entry.get("sessionId") or path))
                agent["prompts"] += 1
        except OSError:
            pass

    if agent["prompts"] == 0:
        try:
            cache = json.loads((root / "stats-cache.json").read_text())
            for row in cache.get("dailyModelTokens", []):
                if row.get("date") in agent["days"]:
                    agent["days"][row["date"]] = sum(int(value or 0) for value in (row.get("tokensByModel") or {}).values())
            for model, row in (cache.get("modelUsage") or {}).items():
                agent["models"][model] = sum(int(row.get(key, 0) or 0) for key in (
                    "inputTokens", "outputTokens", "cacheReadInputTokens", "cacheCreationInputTokens"))
            agent["prompts"] = int(cache.get("totalMessages", 0) or 0)
            sessions = set(range(int(cache.get("totalSessions", 0) or 0)))
        except Exception:
            pass
    agent["sessions"] = len(sessions)
    agent.update(claude_limits(root))
    return finalize_agent(agent)


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


def usage_dicts(obj):
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in ("usage", "token_usage", "total_token_usage", "tokens") and isinstance(value, dict):
                yield value
            yield from usage_dicts(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from usage_dicts(value)


def codex_usage():
    agent = empty_agent("codex", "Codex", cmd("codex") is not None)
    sessions = set()
    roots = [Path(os.path.expanduser(os.environ.get("CODEX_HOME", "~/.codex"))) / "sessions"]
    cutoff = time.time() - 30 * 86400
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*.jsonl"):
            try:
                if path.stat().st_mtime < cutoff:
                    continue
            except OSError:
                continue
            file_model = "codex"
            seen_usage = set()
            try:
                for line in path.open(errors="ignore"):
                    try:
                        entry = json.loads(line)
                    except Exception:
                        continue
                    payload = entry.get("payload") if isinstance(entry.get("payload"), dict) else {}
                    file_model = str(entry.get("model") or payload.get("model") or file_model)
                    for usage in usage_dicts(entry):
                        signature = json.dumps(usage, sort_keys=True, default=str)
                        if signature in seen_usage:
                            continue
                        seen_usage.add(signature)
                        total = token_total(usage)
                        if total <= 0:
                            continue
                        day = local_day(entry.get("timestamp") or payload.get("timestamp"))
                        if str(day) in agent["days"]:
                            agent["days"][str(day)] += total
                        agent["models"][file_model] = agent["models"].get(file_model, 0) + total
                        agent["prompts"] += 1
                if seen_usage:
                    sessions.add(str(path))
            except OSError:
                pass
    agent["sessions"] = len(sessions)
    agent.update(codex_limits())
    return finalize_agent(agent)


def _agents_uncached():
    values = [claude_usage(), codex_usage()]
    return [agent for agent in values if agent["installed"] or agent["prompts"] > 0]


def agents():
    return cached_json("agents", 300, _agents_uncached)


# ------------------------------------------------------------- notifications


def notification_state():
    try:
        data = json.loads(NOTIFICATION_STATE.read_text())
        return {"dnd": bool(data.get("dnd", False)), "history": list(data.get("history", []))[:50]}
    except Exception:
        return {"dnd": False, "history": []}


def save_notification_state(data):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = NOTIFICATION_STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    tmp.replace(NOTIFICATION_STATE)


def notification_action(action_name, payload=""):
    state = notification_state()
    if action_name == "add":
        try:
            state["history"].insert(0, json.loads(payload))
            state["history"] = state["history"][:50]
        except Exception:
            pass
    elif action_name == "clear":
        state["history"] = []
    elif action_name == "dnd":
        state["dnd"] = payload == "true" if payload in ("true", "false") else not state["dnd"]
    save_notification_state(state)
    return state


# ---------------------------------------------------------------- clipboard


def clipboard_list():
    rows = []
    if cmd("cliphist"):
        rc, text, _ = run(["cliphist", "list"])
        if rc == 0:
            for line in text.splitlines()[:30]:
                ident, _, value = line.partition("\t")
                rows.append({"id": ident, "text": value.replace("\n", " ")[:140]})
    elif Path("/usr/bin/copyq").exists():
        for index in range(30):
            rc, text, _ = run(["/usr/bin/copyq", "read", str(index)])
            if rc:
                break
            rows.append({"id": f"copyq:{index}", "text": text.replace("\n", " ")[:140]})
    return rows


def clipboard_paste(ident):
    if ident.startswith("copyq:"):
        index = ident.split(":", 1)[1]
        rc, text, _ = run(["/usr/bin/copyq", "read", index])
        if rc == 0 and cmd("wl-copy"):
            process = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, text=True)
            process.communicate(text)
    elif cmd("cliphist") and cmd("wl-copy"):
        decode = subprocess.Popen(["cliphist", "decode", ident], stdout=subprocess.PIPE)
        copy = subprocess.Popen(["wl-copy"], stdin=decode.stdout)
        decode.stdout.close()
        copy.wait(timeout=3)
    run(["hyprctl", "dispatch", "sendshortcut", "CTRL", "V", "activewindow"])


# ------------------------------------------------------------------ actions


def action(domain, action_name, arg=""):
    if domain == "audio" and cmd("wpctl"):
        if action_name == "volume":
            run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", f"{arg}%"])
        elif action_name == "delta":
            sign = "+" if not str(arg).startswith("-") else "-"
            run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", f"{str(arg).lstrip('+-')}%{sign}"])
        elif action_name == "mute":
            run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        elif action_name == "sink":
            run(["wpctl", "set-default", str(arg)])
        elif action_name.startswith("stream:"):
            run(["wpctl", "set-volume", action_name.split(":", 1)[1], f"{arg}%"])

    elif domain == "network" and cmd("nmcli"):
        if action_name == "toggle":
            run(["nmcli", "radio", "wifi", "off" if network()["enabled"] else "on"])
        elif action_name == "connect":
            rc, _, _ = run(["nmcli", "connection", "up", "id", arg], timeout=15)
            if rc:
                run(["nmcli", "device", "wifi", "connect", arg], timeout=20)
        elif action_name == "settings":
            subprocess.Popen(["kitty", "--class", "nmtui", "nmtui"])

    elif domain == "bluetooth" and cmd("bluetoothctl"):
        if action_name == "toggle":
            run(["bluetoothctl", "power", "off" if bluetooth()["powered"] else "on"])
        elif action_name in ("connect", "disconnect"):
            run(["bluetoothctl", action_name, arg], timeout=12)

    elif domain == "power":
        if action_name == "profile" and cmd("powerprofilesctl"):
            run(["powerprofilesctl", "set", arg])
        elif action_name == "suspend":
            run(["systemctl", "suspend"])
        elif action_name == "lock":
            subprocess.Popen(["hyprlock"])
        elif action_name == "reboot":
            run(["systemctl", "reboot"])
        elif action_name == "shutdown":
            run(["systemctl", "poweroff"])

    elif domain == "updates" and action_name == "run":
        helper = "yay" if cmd("yay") else ("paru" if cmd("paru") else "sudo pacman")
        subprocess.Popen(["kitty", "--class", "system-update", "bash", "-lc",
                          f"{helper} -Syu; printf '\\nPress Enter to close'; read"])

    elif domain == "workspace":
        run(["hyprctl", "dispatch", "workspace", str(arg)])
    return {"ok": True}


# ---------------------------------------------------------------- snapshots


def fast_snapshot():
    return {
        "audio": audio(),
        "brightness": brightness(),
        "workspace": active_workspace(),
        "layout": keyboard_layout(),
    }


def snapshot():
    return {
        "audio": audio(),
        "network": network(),
        "bluetooth": bluetooth(),
        "power": power(),
        "brightness": brightness(),
        "updates": updates(),
        "agents": agents(),
        "workspace": active_workspace(),
        "layout": keyboard_layout(),
        "notifications": notification_state(),
    }


def main():
    if len(sys.argv) == 1 or sys.argv[1] == "snapshot":
        emit(snapshot())
    elif sys.argv[1] == "fast":
        emit(fast_snapshot())
    elif sys.argv[1] == "action":
        emit(action(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else ""))
    elif sys.argv[1] == "notify":
        emit(notification_action(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""))
    elif sys.argv[1] == "clipboard-list":
        emit(clipboard_list())
    elif sys.argv[1] == "clipboard-paste":
        clipboard_paste(sys.argv[2])
        emit({"ok": True})
    else:
        emit({"error": "unknown command"})


if __name__ == "__main__":
    main()
