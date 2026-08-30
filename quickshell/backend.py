#!/usr/bin/env python3
"""Backend for the personal Quickshell desktop shell.

JSON-only stdout contract: QML polls `snapshot`; actions mutate system state.
No Omarchy runtime dependency.
"""
from __future__ import annotations

import datetime as dt
import glob
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()


def run(args, timeout=4, check=False):
    try:
        p = subprocess.run(args, text=True, capture_output=True, timeout=timeout, check=False)
        if check and p.returncode:
            raise RuntimeError(p.stderr.strip() or f"{args[0]} exited {p.returncode}")
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 127, "", str(e)


def out(data):
    print(json.dumps(data, ensure_ascii=False, separators=(",", ":")))


def command(name):
    return shutil.which(name)


def audio():
    data = {"volume": 0, "muted": False, "sinks": [], "streams": []}
    rc, s, _ = run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]) 
    if rc == 0:
        m = re.search(r"Volume:\s*([0-9.]+)", s)
        if m:
            data["volume"] = max(0, min(150, round(float(m.group(1)) * 100)))
        data["muted"] = "[MUTED]" in s

    rc, text, _ = run(["wpctl", "status", "-n"], timeout=5)
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
            if not line.endswith("Sinks:") and not line.endswith("Streams:"):
                section = ""
            continue
        m = re.search(r"(\*)?\s*(\d+)\.\s+(.+?)(?:\s+\[vol:.*)?$", line)
        if not m or section not in ("sinks", "streams"):
            continue
        item = {"id": int(m.group(2)), "name": m.group(3).strip(), "default": bool(m.group(1))}
        if section == "streams":
            rcv, vs, _ = run(["wpctl", "get-volume", str(item["id"])])
            vm = re.search(r"Volume:\s*([0-9.]+)", vs)
            item["volume"] = round(float(vm.group(1)) * 100) if rcv == 0 and vm else 0
            item["muted"] = "[MUTED]" in vs
        data[section].append(item)
    return data


def network():
    data = {"enabled": False, "active": "", "networks": []}
    if not command("nmcli"):
        return data
    rc, s, _ = run(["nmcli", "-t", "-f", "WIFI", "general"])
    data["enabled"] = rc == 0 and "enabled" in s.lower()
    rc, s, _ = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"])
    if rc == 0:
        for line in s.splitlines():
            if line.endswith(":802-11-wireless") or line.endswith(":wifi"):
                data["active"] = line.rsplit(":", 1)[0].replace("\\:", ":")
                break
    rc, s, _ = run(["nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"], timeout=8)
    if rc == 0:
        seen = set()
        for line in s.splitlines():
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
    if not command("bluetoothctl"):
        return data
    rc, s, _ = run(["bluetoothctl", "show"])
    data["powered"] = rc == 0 and "Powered: yes" in s
    rc, s, _ = run(["bluetoothctl", "devices", "Paired"])
    if rc != 0:
        rc, s, _ = run(["bluetoothctl", "paired-devices"])
    if rc == 0:
        for line in s.splitlines():
            m = re.match(r"Device\s+([0-9A-Fa-f:]+)\s+(.+)$", line)
            if not m:
                continue
            mac, name = m.groups()
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
    if command("powerprofilesctl"):
        rc, s, _ = run(["powerprofilesctl", "get"])
        if rc == 0:
            data["profile"] = s
        rc, s, _ = run(["powerprofilesctl", "list"])
        if rc == 0:
            data["profiles"] = re.findall(r"(?:\* )?([a-z-]+):", s)
    bats = list(Path("/sys/class/power_supply").glob("BAT*"))
    if bats:
        try:
            data["battery"] = int((bats[0] / "capacity").read_text().strip())
            data["status"] = (bats[0] / "status").read_text().strip()
        except OSError:
            pass
    rc, s, _ = run(["uptime", "-p"])
    if rc == 0:
        data["uptime"] = s.replace("up ", "")
    return data


def brightness():
    if not command("brightnessctl"):
        return -1
    rc, s, _ = run(["brightnessctl", "-m"])
    if rc:
        return -1
    parts = s.split(",")
    if len(parts) >= 4:
        try:
            return int(parts[3].rstrip("%"))
        except ValueError:
            pass
    return -1


def _updates_uncached():
    count = 0
    if command("checkupdates"):
        _, s, _ = run(["checkupdates"], timeout=12)
        if s:
            count += len([line for line in s.splitlines() if line.strip()])
    aur = []
    for helper in ("yay", "paru"):
        if command(helper):
            _, s, _ = run([helper, "-Qua"], timeout=15)
            if s:
                aur = [line for line in s.splitlines() if line.strip()]
            break
    count += len(aur)
    return {"count": count}


def active_workspace():
    rc, s, _ = run(["hyprctl", "-j", "activeworkspace"])
    if rc == 0:
        try:
            return int(json.loads(s).get("id", 1))
        except Exception:
            pass
    return 1


def keyboard_layout():
    rc, s, _ = run(["hyprctl", "-j", "devices"])
    if rc == 0:
        try:
            devices = json.loads(s)
            for keyboard in devices.get("keyboards", []):
                if keyboard.get("main"):
                    return str(keyboard.get("active_keymap", ""))
        except Exception:
            pass
    return ""


def _token_total(usage):
    if not isinstance(usage, dict):
        return 0
    keys = (
        "input_tokens", "output_tokens", "cache_read_input_tokens",
        "cache_creation_input_tokens", "inputTokens", "outputTokens",
        "cacheReadInputTokens", "cacheCreationInputTokens",
    )
    return sum(int(usage.get(key, 0) or 0) for key in keys)


def claude_usage():
    root = Path(os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")))
    today = dt.datetime.now().astimezone().date()
    day_tokens = {str(today - dt.timedelta(days=i)): 0 for i in range(6, -1, -1)}
    by_model = {}
    sessions = set()
    prompts = 0
    for path in (root / "projects").rglob("*.jsonl") if (root / "projects").exists() else []:
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
                total = _token_total(usage)
                if total <= 0:
                    continue
                stamp = entry.get("timestamp") or message.get("timestamp")
                try:
                    day = dt.datetime.fromisoformat(str(stamp).replace("Z", "+00:00")).astimezone().date()
                except Exception:
                    day = today
                model = str(message.get("model") or entry.get("model") or "claude")
                by_model[model] = by_model.get(model, 0) + total
                if str(day) in day_tokens:
                    day_tokens[str(day)] += total
                sessions.add(str(entry.get("sessionId") or path))
                prompts += 1
        except OSError:
            pass

    if prompts == 0:
        try:
            cache = json.loads((root / "stats-cache.json").read_text())
            for row in cache.get("dailyModelTokens", []):
                if row.get("date") in day_tokens:
                    day_tokens[row["date"]] = sum(int(value or 0) for value in (row.get("tokensByModel") or {}).values())
            for model, row in (cache.get("modelUsage") or {}).items():
                by_model[model] = sum(int(row.get(key, 0) or 0) for key in (
                    "inputTokens", "outputTokens", "cacheReadInputTokens", "cacheCreationInputTokens"))
            prompts = int(cache.get("totalMessages", 0) or 0)
            sessions = set(range(int(cache.get("totalSessions", 0) or 0)))
        except Exception:
            pass

    return {
        "id": "claude", "name": "Claude Code", "installed": command("claude") is not None,
        "today": day_tokens.get(str(today), 0), "week": sum(day_tokens.values()),
        "prompts": prompts, "sessions": len(sessions),
        "days": [{"date": key, "tokens": value} for key, value in day_tokens.items()],
        "models": [{"name": key, "tokens": value} for key, value in sorted(by_model.items(), key=lambda item: -item[1])[:8]],
    }


def codex_usage():
    today = dt.datetime.now().astimezone().date()
    day_tokens = {str(today - dt.timedelta(days=i)): 0 for i in range(6, -1, -1)}
    by_model = {}
    sessions = set()
    prompts = 0
    roots = [
        Path(os.path.expanduser(os.environ.get("CODEX_HOME", "~/.codex"))) / "sessions",
        HOME / ".local/share/opencode/storage/session",
    ]
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*.jsonl"):
            try:
                for line in path.open(errors="ignore"):
                    if "usage" not in line and "token" not in line:
                        continue
                    try:
                        entry = json.loads(line)
                    except Exception:
                        continue
                    usage = entry.get("usage") or entry.get("token_usage") or entry.get("tokens") or {}
                    total = _token_total(usage)
                    if total <= 0 and isinstance(usage, dict):
                        total = sum(int(value or 0) for key, value in usage.items()
                                    if "token" in key.lower() and isinstance(value, (int, float)))
                    if total <= 0:
                        continue
                    stamp = entry.get("timestamp") or entry.get("created_at") or entry.get("time")
                    try:
                        day = dt.datetime.fromisoformat(str(stamp).replace("Z", "+00:00")).astimezone().date()
                    except Exception:
                        day = today
                    model = str(entry.get("model") or entry.get("model_id") or "codex")
                    by_model[model] = by_model.get(model, 0) + total
                    if str(day) in day_tokens:
                        day_tokens[str(day)] += total
                    sessions.add(str(path))
                    prompts += 1
            except OSError:
                pass
    return {
        "id": "codex", "name": "Codex", "installed": command("codex") is not None,
        "today": day_tokens.get(str(today), 0), "week": sum(day_tokens.values()),
        "prompts": prompts, "sessions": len(sessions),
        "days": [{"date": key, "tokens": value} for key, value in day_tokens.items()],
        "models": [{"name": key, "tokens": value} for key, value in sorted(by_model.items(), key=lambda item: -item[1])[:8]],
    }


def _agents_uncached():
    return [item for item in (claude_usage(), codex_usage()) if item["installed"] or item["prompts"] > 0]


CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "dots-shell"


def cached_json(name, ttl, producer):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = CACHE_DIR / f"{name}.json"
    try:
        if path.exists() and (dt.datetime.now().timestamp() - path.stat().st_mtime) < ttl:
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


def agents():
    return cached_json("agents", 300, _agents_uncached)


def updates():
    return cached_json("updates", 600, _updates_uncached)


def fast_snapshot():
    return {
        "audio": audio(),
        "brightness": brightness(),
        "workspace": active_workspace(),
        "layout": keyboard_layout(),
    }


STATE_DIR = HOME / ".local/state/dots-shell"
NOTIFICATION_STATE = STATE_DIR / "notifications.json"


def notification_state():
    try:
        raw = json.loads(NOTIFICATION_STATE.read_text())
        return {
            "dnd": bool(raw.get("dnd", False)),
            "history": list(raw.get("history", []))[:50],
        }
    except Exception:
        return {"dnd": False, "history": []}


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


def action(domain, action_name, arg=""):
    if domain == "audio":
        if action_name == "volume":
            run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", f"{arg}%"])
        elif action_name == "delta":
            sign = "+" if not str(arg).startswith("-") else "-"
            value = str(arg).lstrip("+-")
            run(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", f"{value}%{sign}"])
        elif action_name == "mute":
            run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        elif action_name == "sink":
            run(["wpctl", "set-default", str(arg)])
        elif action_name.startswith("stream:"):
            stream_id = action_name.split(":", 1)[1]
            run(["wpctl", "set-volume", stream_id, f"{arg}%"])
    elif domain == "network":
        if action_name == "toggle":
            run(["nmcli", "radio", "wifi", "off" if network()["enabled"] else "on"])
        elif action_name == "connect":
            rc, _, _ = run(["nmcli", "connection", "up", "id", arg], timeout=15)
            if rc:
                run(["nmcli", "device", "wifi", "connect", arg], timeout=20)
        elif action_name == "settings":
            subprocess.Popen(["kitty", "--class", "nmtui", "nmtui"])
    elif domain == "bluetooth":
        if action_name == "toggle":
            run(["bluetoothctl", "power", "off" if bluetooth()["powered"] else "on"])
        elif action_name in ("connect", "disconnect"):
            run(["bluetoothctl", action_name, arg], timeout=12)
    elif domain == "power":
        if action_name == "profile":
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
        helper = "yay" if command("yay") else ("paru" if command("paru") else "sudo pacman")
        subprocess.Popen(["kitty", "--class", "system-update", "bash", "-lc",
                          f"{helper} -Syu; printf '\\nPress Enter to close'; read"])
    elif domain == "workspace":
        run(["hyprctl", "dispatch", "workspace", str(arg)])
    return {"ok": True}


def save_notification_state(data):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = NOTIFICATION_STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    tmp.replace(NOTIFICATION_STATE)


def notification_action(action_name, payload=""):
    state = notification_state()
    if action_name == "add":
        try:
            item = json.loads(payload)
            state["history"].insert(0, item)
            state["history"] = state["history"][:50]
        except Exception:
            pass
    elif action_name == "clear":
        state["history"] = []
    elif action_name == "dnd":
        if payload in ("true", "false"):
            state["dnd"] = payload == "true"
        else:
            state["dnd"] = not state["dnd"]
    save_notification_state(state)
    return state


def clipboard_list():
    rows = []
    if command("cliphist"):
        rc, s, _ = run(["cliphist", "list"])
        if rc == 0:
            for line in s.splitlines()[:30]:
                ident, _, text = line.partition("\t")
                rows.append({"id": ident, "text": text.replace("\n", " ")[:140]})
    elif command("copyq"):
        for i in range(30):
            rc, s, _ = run(["copyq", "read", str(i)])
            if rc:
                break
            rows.append({"id": f"copyq:{i}", "text": s.replace("\n", " ")[:140]})
    return rows


def clipboard_paste(ident):
    if ident.startswith("copyq:"):
        idx = ident.split(":", 1)[1]
        rc, s, _ = run(["copyq", "read", idx])
        if rc == 0 and command("wl-copy"):
            process = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, text=True)
            process.communicate(s)
    elif command("cliphist") and command("wl-copy"):
        decode = subprocess.Popen(["cliphist", "decode", ident], stdout=subprocess.PIPE)
        copy = subprocess.Popen(["wl-copy"], stdin=decode.stdout)
        decode.stdout.close()
        copy.wait(timeout=3)
    run(["hyprctl", "dispatch", "sendshortcut", "CTRL", "V", "activewindow"])


def main():
    if len(sys.argv) == 1 or sys.argv[1] == "snapshot":
        out(snapshot())
    elif sys.argv[1] == "fast":
        out(fast_snapshot())
    elif sys.argv[1] == "action":
        out(action(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else ""))
    elif sys.argv[1] == "notify":
        out(notification_action(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""))
    elif sys.argv[1] == "clipboard-list":
        out(clipboard_list())
    elif sys.argv[1] == "clipboard-paste":
        clipboard_paste(sys.argv[2])
        out({"ok": True})
    else:
        out({"error": "unknown command"})


if __name__ == "__main__":
    main()
