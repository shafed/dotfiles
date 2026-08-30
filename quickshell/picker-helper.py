#!/usr/bin/env python3
"""Data/action bridge for Quickshell text pickers."""

from __future__ import annotations

import glob
import json
import math
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HOME = Path.home()
ROOT = HOME / "github/dotfiles"
KITTY_SESSIONS = ROOT / "kitty/sessions"
TRANSIENT_SESSIONS = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "kitty-sessions"
YOUTUBE = ROOT / "scripts/youtube.sh"
LIB = ROOT / "scripts/lib.sh"
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

# Search-frequency ranking + fuzzy-match highlighting, same approach as
# quickshell/youtube-helper.py: a picked row's key gets one count bumped in
# usage.tsv, and a log2 bonus nudges it up on later searches without letting a
# frequently-opened row outrank a genuinely better match.
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "quickpicker"
USAGE_FILE = CACHE_DIR / "usage.tsv"
FREQUENCY_WEIGHT = float(os.environ.get("DOTFILES_QUICKPICKER_FREQUENCY_WEIGHT", "0.65"))


def run(args, timeout=8, env=None):
    try:
        proc = subprocess.run(
            [str(arg) for arg in args],
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
            env=env,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except Exception as exc:
        return 127, "", str(exc)


def emit(value):
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))


def fuzzy_score(text, query):
    q = query.strip().lower()
    if not q:
        return 0
    hay = text.lower()
    direct = hay.find(q)
    if direct >= 0:
        return 10000 - direct * 10 - len(hay)
    pos = -1
    gap = 0
    for char in q:
        nxt = hay.find(char, pos + 1)
        if nxt < 0:
            return -1
        if pos >= 0:
            gap += nxt - pos - 1
        pos = nxt
    return 5000 - gap * 8 - pos


def fuzzy_positions(text, query):
    """Character indices in `text` that satisfied `query`, for highlighting.

    Mirrors youtube-helper.py's fuzzy_positions: a full substring match
    highlights contiguously, otherwise each query character highlights the
    first place it was found scanning left to right (the same greedy walk
    fuzzy_score uses, so highlights always match what actually scored).
    """
    value = str(text or "")
    hay = value.lower()
    positions = set()
    for raw_term in str(query or "").strip().lower().split():
        term = raw_term.strip()
        if not term:
            continue
        direct = hay.find(term)
        if direct >= 0:
            positions.update(range(direct, direct + len(term)))
            continue
        pos = -1
        matched = []
        for char in term:
            nxt = hay.find(char, pos + 1)
            if nxt < 0:
                matched = []
                break
            matched.append(nxt)
            pos = nxt
        positions.update(matched)
    return sorted(positions)


def load_usage():
    counts = {}
    if not USAGE_FILE.exists():
        return counts
    try:
        for line in USAGE_FILE.read_text(errors="ignore").splitlines():
            parts = line.rsplit("\t", 1)
            if len(parts) != 2:
                continue
            ident, raw_count = parts
            try:
                counts[ident] = max(0, int(raw_count))
            except ValueError:
                pass
    except OSError:
        pass
    return counts


def record_usage(key):
    if not key:
        return
    counts = load_usage()
    counts[key] = counts.get(key, 0) + 1
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    ordered = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    USAGE_FILE.write_text("".join(f"{item_key}\t{count}\n" for item_key, count in ordered))


def filter_rows(rows, query, provider):
    query = query.strip()
    usage = load_usage()
    ranked = []
    for index, row in enumerate(rows):
        text = " ".join(str(row.get(key, "")) for key in ("title", "subtitle", "badge", "id"))
        score = fuzzy_score(text, query)
        if score < 0:
            continue
        count = usage.get(f"{provider}:{row.get('id', '')}", 0)
        # Scaled to sit alongside fuzzy_score's ~10-unit position penalties: a
        # frequently-picked row can leapfrog near-ties but never a stronger
        # positional match.
        bonus = FREQUENCY_WEIGHT * math.log2(count + 1) * 50 if query and count > 0 else 0
        ranked.append((score + bonus, -index, count, row))
    ranked.sort(key=lambda item: (item[0], item[1]), reverse=True)

    result = []
    for _, _, count, row in ranked:
        item = dict(row)
        item["usage"] = count
        item["titleMatches"] = fuzzy_positions(item.get("title", ""), query)
        item["subtitleMatches"] = fuzzy_positions(item.get("subtitle", ""), query)
        result.append(item)
    return result


def main_kitty_socket():
    kitty = shutil.which("kitty") or "/usr/bin/kitty"
    for path in sorted(Path("/tmp").glob("kitty-*")):
        try:
            if not path.is_socket():
                continue
        except OSError:
            continue
        pid = path.name.rsplit("-", 1)[-1]
        rc, args, _ = run(["ps", "-p", pid, "-o", "args="], timeout=2)
        if rc != 0 or "+kitten panel" in args:
            continue
        if args.startswith(kitty) or args.startswith("kitty") or "/kitty " in args:
            return str(path)
    return ""


def ensure_main_kitty():
    sock = main_kitty_socket()
    if sock:
        return sock
    kitty = shutil.which("kitty")
    if not kitty:
        return ""
    subprocess.Popen(
        [kitty],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    for _ in range(40):
        time.sleep(0.1)
        sock = main_kitty_socket()
        if sock:
            return sock
    return ""


def kitty_remote(sock, *args, timeout=6):
    kitty = shutil.which("kitty")
    if not kitty or not sock:
        return 127, "", "kitty socket unavailable"
    return run([kitty, "@", "--to", f"unix:{sock}", *args], timeout=timeout)


def kitty_state(sock=None):
    sock = sock or main_kitty_socket()
    if not sock:
        return []
    rc, text, _ = kitty_remote(sock, "ls")
    if rc:
        return []
    try:
        return json.loads(text)
    except Exception:
        return []


def focus_main_kitty():
    if shutil.which("hyprctl"):
        run(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "class:kitty" })'], timeout=2)


def session_rows(query=""):
    rows = {}
    for os_window in kitty_state():
        os_focused = bool(os_window.get("is_focused", False))
        for tab in os_window.get("tabs", []):
            tab_focused = bool(tab.get("is_focused", False))
            for window in tab.get("windows", []):
                name = str(window.get("session_name") or "")
                if not name:
                    continue
                env = window.get("env") if isinstance(window.get("env"), dict) else {}
                cwd = str(env.get("PWD") or window.get("cwd") or "")
                stamp = float(window.get("last_focused_at") or 0)
                focused = os_focused and tab_focused
                current = rows.get(name)
                candidate = {
                    "id": name,
                    "kind": "session",
                    "title": name,
                    "subtitle": cwd.replace(str(HOME), "~", 1) if cwd.startswith(str(HOME)) else cwd,
                    "badge": "CURRENT" if focused else "",
                    "_stamp": stamp,
                }
                if current is None or focused or stamp > current["_stamp"]:
                    rows[name] = candidate
    values = sorted(rows.values(), key=lambda row: (-row["_stamp"], row["title"].lower()))
    for row in values:
        row.pop("_stamp", None)
    return filter_rows(values, query, "sessions")


def ssh_hosts():
    root = HOME / ".ssh/config"
    if not root.exists():
        return []
    queue = [root]
    seen_files = set()
    hosts = set()
    while queue:
        path = queue.pop(0).expanduser()
        try:
            path = path.resolve()
        except OSError:
            continue
        if path in seen_files or not path.is_file():
            continue
        seen_files.add(path)
        try:
            lines = path.read_text(errors="ignore").splitlines()
        except OSError:
            continue
        for raw in lines:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = line.split()
            if not parts:
                continue
            key = parts[0].lower()
            if key == "include":
                for pattern in parts[1:]:
                    expanded = os.path.expanduser(pattern)
                    if not os.path.isabs(expanded):
                        expanded = str(path.parent / expanded)
                    queue.extend(Path(match) for match in glob.glob(expanded))
            elif key == "host":
                for host in parts[1:]:
                    if host.startswith("!") or any(ch in host for ch in "*?"):
                        continue
                    hosts.add(host)
    return sorted(hosts)


def project_rows(query=""):
    rows = []
    if KITTY_SESSIONS.is_dir():
        for path in sorted(KITTY_SESSIONS.glob("*.kitty-session")):
            rows.append({
                "id": f"named:{path.stem}",
                "kind": "named",
                "title": path.stem,
                "subtitle": "named kitty session",
                "badge": "SESSION",
            })

    if shutil.which("zoxide"):
        rc, text, _ = run(["zoxide", "query", "-l"], timeout=5)
        if rc == 0:
            for raw in text.splitlines():
                path = raw.strip()
                if not path:
                    continue
                rows.append({
                    "id": f"dir:{path}",
                    "kind": "dir",
                    "title": Path(path).name or path,
                    "subtitle": path.replace(str(HOME), "~", 1) if path.startswith(str(HOME)) else path,
                    "badge": "DIR",
                })

    for host in ssh_hosts():
        rows.append({
            "id": f"ssh:{host}",
            "kind": "ssh",
            "title": f"ssh-{host}",
            "subtitle": host,
            "badge": "SSH",
        })
    return filter_rows(rows, query, "projects")


def session_exists(state, name):
    return any(
        str(window.get("session_name") or "") == name
        for os_window in state
        for tab in os_window.get("tabs", [])
        for window in tab.get("windows", [])
    )


def session_for_path(state, target):
    target = os.path.realpath(target)
    best = None
    for os_window in state:
        for tab in os_window.get("tabs", []):
            for window in tab.get("windows", []):
                name = str(window.get("session_name") or "")
                env = window.get("env") if isinstance(window.get("env"), dict) else {}
                cwd = str(env.get("PWD") or window.get("cwd") or "")
                if not name or not cwd or os.path.realpath(cwd) != target:
                    continue
                stamp = float(window.get("last_focused_at") or 0)
                if best is None or stamp > best[0]:
                    best = (stamp, name)
    return best[1] if best else ""


def goto_session(sock, session_arg):
    rc, _, _ = kitty_remote(sock, "action", "goto_session", str(session_arg))
    if rc == 0:
        focus_main_kitty()
        return True
    return False


def open_project(ident):
    sock = ensure_main_kitty()
    if not sock:
        return False
    state = kitty_state(sock)
    TRANSIENT_SESSIONS.mkdir(parents=True, exist_ok=True)

    if ident.startswith("named:"):
        name = ident.split(":", 1)[1]
        path = KITTY_SESSIONS / f"{name}.kitty-session"
        return goto_session(sock, path if path.exists() else name)

    if ident.startswith("ssh:"):
        host = ident.split(":", 1)[1]
        safe = re.sub(r"[^A-Za-z0-9._-]+", "_", host).strip("_") or "host"
        base = f"ssh-{safe}"
        name = base
        suffix = 2
        while session_exists(state, name):
            transient = TRANSIENT_SESSIONS / f"{name}.kitty-session"
            if transient.exists():
                return goto_session(sock, transient)
            name = f"{base}-{suffix}"
            suffix += 1
        path = TRANSIENT_SESSIONS / f"{name}.kitty-session"
        path.write_text(
            f'layout horizontal\nlaunch --title "ssh-{host}" ssh {host}\nfocus\nfocus_os_window\n'
        )
        return goto_session(sock, path)

    if ident.startswith("dir:"):
        selected = ident.split(":", 1)[1]
        if not Path(selected).is_dir():
            return False
        real = os.path.realpath(selected)
        existing = session_for_path(state, real)
        if existing:
            transient = TRANSIENT_SESSIONS / f"{existing}.kitty-session"
            if shutil.which("zoxide"):
                run(["zoxide", "add", real], timeout=3)
            return goto_session(sock, transient if transient.exists() else existing)

        base = Path(real).name or "session"
        safe = re.sub(r"[^A-Za-z0-9._-]+", "_", base).strip("_") or "session"
        name = safe
        suffix = 2
        while session_exists(state, name):
            name = f"{safe}-{suffix}"
            suffix += 1
        path = TRANSIENT_SESSIONS / f"{name}.kitty-session"
        path.write_text(
            f"layout horizontal\ncd {real}\nlaunch --title {shlex.quote(base)}\nfocus\nfocus_os_window\n"
        )
        if shutil.which("zoxide"):
            run(["zoxide", "add", real], timeout=3)
        return goto_session(sock, path)
    return False


def open_session(name):
    sock = ensure_main_kitty()
    if not sock:
        return False
    transient = TRANSIENT_SESSIONS / f"{name}.kitty-session"
    named = KITTY_SESSIONS / f"{name}.kitty-session"
    target = transient if transient.exists() else (named if named.exists() else name)
    return goto_session(sock, target)


def delete_session(name):
    sock = main_kitty_socket()
    if not sock:
        return False
    rc, _, _ = kitty_remote(sock, "action", "close_session", name)
    return rc == 0


def parse_youtube_rows(text):
    rows = []
    for raw in text.splitlines():
        cols = ANSI_RE.sub("", raw).split("\t")
        if len(cols) < 5:
            continue
        kind, ident, handle, title, duration = cols[:5]
        if kind == "video" and ident:
            rows.append({
                "id": f"video:{ident}",
                "kind": "video",
                "title": title or ident,
                "subtitle": duration,
                "badge": "VIDEO",
            })
        elif kind == "channel" and ident:
            rows.append({
                "id": f"channel:{handle or ident}",
                "kind": "channel",
                "title": title or handle or ident,
                "subtitle": handle,
                "badge": "CHANNEL",
            })
    return rows


def youtube_rows(query=""):
    query = query.strip()
    if not query:
        return [
            {"id": "later:WL", "kind": "page", "title": "Watch later", "subtitle": "YouTube playlist", "badge": "WL"},
            {"id": "history:history", "kind": "page", "title": "Watch history", "subtitle": "YouTube history", "badge": "HISTORY"},
            {"id": "channels:channels", "kind": "page", "title": "Subscriptions", "subtitle": "Channels feed", "badge": "CHANNELS"},
        ]
    if not YOUTUBE.exists():
        return []

    def search(mode):
        return run(["bash", str(YOUTUBE), "--ytsearch", mode, query], timeout=15)

    rows = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        for rc, text, _ in pool.map(search, ("videos", "channels")):
            if rc == 0 or text:
                rows.extend(parse_youtube_rows(text))

    seen = set()
    result = []
    for row in rows:
        if row["id"] in seen:
            continue
        seen.add(row["id"])
        result.append(row)
    return result[:40]


def open_youtube(ident):
    if ident.startswith("video:"):
        url = "https://www.youtube.com/watch?v=" + ident.split(":", 1)[1]
    elif ident.startswith("channel:"):
        target = ident.split(":", 1)[1]
        url = (
            "https://www.youtube.com/" + target + "/videos"
            if target.startswith("@")
            else "https://www.youtube.com/channel/" + target + "/videos"
        )
    elif ident.startswith("later:"):
        url = "https://www.youtube.com/playlist?list=WL"
    elif ident.startswith("history:"):
        url = "https://www.youtube.com/feed/history"
    elif ident.startswith("channels:"):
        url = "https://www.youtube.com/feed/channels"
    else:
        return False

    browser = os.environ.get("DOTFILES_BROWSER_BIN", "helium-browser")
    if not shutil.which("hyprctl") or not LIB.exists():
        try:
            subprocess.Popen(
                [browser, url],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return True
        except Exception:
            return False

    script = r"""
source "$1"
url="$2"
ws=4
if [[ -n "$(browser_window_off_workspace "$ws")" ]]; then
  open_in_new_browser_window "$url" "$ws"
else
  switch_to_workspace_for_browser "$ws"
  open_browser_url "$url"
  move_browser_when_up "$ws"
fi
"""
    subprocess.Popen(
        ["bash", "-lc", script, "_", str(LIB), url],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return True


def active_window():
    if not shutil.which("hyprctl"):
        return {"address": "", "class": ""}
    rc, text, _ = run(["hyprctl", "-j", "activewindow"], timeout=2)
    if rc:
        return {"address": "", "class": ""}
    try:
        data = json.loads(text)
    except Exception:
        return {"address": "", "class": ""}
    return {"address": str(data.get("address") or ""), "class": str(data.get("class") or "")}


def scratch_paste(target, text):
    if not text:
        return True
    wl_copy = shutil.which("wl-copy")
    if not wl_copy:
        return False
    proc = subprocess.Popen([wl_copy], stdin=subprocess.PIPE, text=True)
    proc.communicate(text)

    time.sleep(0.12)
    if target and target != "none" and shutil.which("hyprctl"):
        run(["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{target}" }})'], timeout=2)
        for _ in range(20):
            if active_window()["address"] == target:
                break
            time.sleep(0.05)

    row = active_window()
    wtype = shutil.which("wtype")
    if not wtype:
        return False
    args = [wtype, "-M", "ctrl"]
    if row["class"].lower() == "kitty":
        args += ["-M", "shift"]
    args += ["-k", "v"]
    if row["class"].lower() == "kitty":
        args += ["-m", "shift"]
    args += ["-m", "ctrl"]
    run(args, timeout=3)
    return True


def list_provider(provider, query):
    if provider == "projects":
        return project_rows(query)
    if provider == "sessions":
        return session_rows(query)
    if provider == "youtube":
        return youtube_rows(query)
    return []


def open_provider(provider, ident):
    if provider == "projects":
        return open_project(ident)
    if provider == "sessions":
        return open_session(ident)
    if provider == "youtube":
        return open_youtube(ident)
    return False


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "list":
        emit(list_provider(
            sys.argv[2] if len(sys.argv) > 2 else "",
            sys.argv[3] if len(sys.argv) > 3 else "",
        ))
    elif command == "open":
        provider = sys.argv[2] if len(sys.argv) > 2 else ""
        ident = sys.argv[3] if len(sys.argv) > 3 else ""
        if provider in ("projects", "sessions"):
            record_usage(f"{provider}:{ident}")
        emit({"ok": bool(open_provider(provider, ident))})
    elif command == "delete":
        name = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "sessions" else ""
        emit({"ok": bool(delete_session(name))})
    elif command == "active-window":
        emit(active_window())
    elif command == "scratch-paste":
        target = sys.argv[2] if len(sys.argv) > 2 else ""
        text = sys.argv[3] if len(sys.argv) > 3 else ""
        emit({"ok": scratch_paste(target, text)})
    else:
        emit({"error": "unknown command"})


if __name__ == "__main__":
    main()
