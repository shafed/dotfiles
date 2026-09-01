#!/usr/bin/env python3
"""Data/action bridge for the native Quickshell YouTube picker."""

from __future__ import annotations

import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

HOME = Path.home()
ROOT = HOME / "github/dotfiles"
YOUTUBE = ROOT / "scripts/youtube.sh"
LIB = ROOT / "scripts/lib.sh"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "youtube-fzf"
USAGE_FILE = CACHE / "usage.tsv"
FREQUENCY_WEIGHT = float(os.environ.get("DOTFILES_YOUTUBE_FREQUENCY_WEIGHT", "0.65"))
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def run(args, timeout=30, env=None):
    try:
        proc = subprocess.run(
            [str(arg) for arg in args], text=True, capture_output=True,
            timeout=timeout, check=False, env=env,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except Exception as exc:
        return 127, "", str(exc)


def emit(value):
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))


def clean(value):
    return ANSI_RE.sub("", str(value or "")).strip()


def load_usage():
    counts = {}
    if not USAGE_FILE.exists():
        return counts
    try:
        for line in USAGE_FILE.read_text(errors="ignore").splitlines():
            ident, sep, raw_count = line.rpartition("\t")
            if not sep:
                continue
            try:
                counts[ident] = max(0, int(raw_count))
            except ValueError:
                pass
    except OSError:
        pass
    return counts


def record_usage(ident):
    ident = clean(ident)
    if not ident or ident.startswith(("later:", "history:", "channels:")):
        return
    counts = load_usage()
    counts[ident] = counts.get(ident, 0) + 1
    CACHE.mkdir(parents=True, exist_ok=True)
    ordered = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    USAGE_FILE.write_text("".join(f"{item_id}\t{count}\n" for item_id, count in ordered))


def fuzzy_positions(text, query):
    value = str(text or "")
    hay = value.casefold()
    positions = set()
    for term in str(query or "").casefold().split():
        term = term.strip()
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


def decorate_rows(rows, query=""):
    usage = load_usage()
    query = str(query or "").strip()
    weighted = []
    for base_rank, row in enumerate(rows):
        item = dict(row)
        count = usage.get(str(item.get("id") or ""), 0)
        bonus = FREQUENCY_WEIGHT * math.log2(count + 1) if query and count > 0 else 0.0
        weighted.append((base_rank - bonus, base_rank, item, count))
    if query:
        weighted.sort(key=lambda item: (item[0], item[1]))
    result = []
    for _, _, item, count in weighted:
        item["usage"] = count
        item["titleMatches"] = fuzzy_positions(item.get("title", ""), query)
        item["subtitleMatches"] = fuzzy_positions(item.get("subtitle", ""), query)
        result.append(item)
    return result


def video_badge(title, display=""):
    text = f"{clean(title)} {clean(display)}"
    if "● LIVE" in text:
        return "LIVE"
    if "was live" in text or "(was live)" in text:
        return "WAS LIVE"
    return "VIDEO"


def clean_video_title(title):
    value = clean(title)
    return value.replace("  ● LIVE", "").replace(" ● LIVE", "").replace(
        "  (was live)", ""
    ).replace(" (was live)", "").strip()


def video_row(ident, title, duration="", channel="", display=""):
    ident = clean(ident)
    return {
        "id": f"video:{ident}", "kind": "video", "videoId": ident,
        "title": clean_video_title(title) or ident,
        "subtitle": " · ".join(part for part in (clean(duration), clean(channel)) if part),
        "duration": clean(duration), "channel": clean(channel),
        "badge": video_badge(title, display),
        "thumbnail": f"https://i.ytimg.com/vi/{ident}/hqdefault.jpg" if ident else "",
    }


def channel_row(ident, handle, title):
    ident, handle = clean(ident), clean(handle)
    title = clean(title) or handle or ident
    target = handle if handle.startswith("@") else ident
    return {
        "id": f"channel:{target}", "kind": "channel", "target": target,
        "title": title, "subtitle": handle, "duration": "", "channel": "",
        "badge": "CHANNEL", "thumbnail": "",
    }


def page_row(ident, title, subtitle, badge):
    return {
        "id": ident, "kind": "page", "title": title, "subtitle": subtitle,
        "duration": "", "channel": "", "badge": badge, "thumbnail": "",
    }


def parse_shared_rows(text):
    rows = []
    for raw in text.splitlines():
        cols = ANSI_RE.sub("", raw).split("\t")
        if len(cols) < 5:
            continue
        kind, ident, meta, title, duration = cols[:5]
        display = cols[5] if len(cols) > 5 else ""
        if kind == "video" and ident:
            rows.append(video_row(ident, title, duration, meta, display))
        elif kind == "channel" and ident:
            rows.append(channel_row(ident, meta, title))
    return rows


def parse_channel_rows(text):
    rows = []
    for raw in text.splitlines():
        cols = ANSI_RE.sub("", raw).split("\t")
        if len(cols) < 2:
            continue
        ident, title = cols[:2]
        duration = cols[2] if len(cols) > 2 else ""
        if ident:
            rows.append(video_row(ident, title, duration))
    return rows


def fuzzy_score(text, query):
    q = query.strip().lower()
    if not q:
        return 0
    hay = text.lower()
    direct = hay.find(q)
    if direct >= 0:
        return 10000 - direct * 10 - len(hay)
    pos, gap = -1, 0
    for char in q:
        nxt = hay.find(char, pos + 1)
        if nxt < 0:
            return -1
        if pos >= 0:
            gap += nxt - pos - 1
        pos = nxt
    return 5000 - gap * 8 - pos


def filter_rows(rows, query):
    if not query.strip():
        return rows
    ranked = []
    for index, row in enumerate(rows):
        text = " ".join(str(row.get(key, "")) for key in (
            "title", "subtitle", "channel", "duration", "badge"
        ))
        score = fuzzy_score(text, query)
        if score >= 0:
            ranked.append((score, -index, row))
    ranked.sort(key=lambda item: (item[0], item[1]), reverse=True)
    return [row for _, _, row in ranked]


def dedupe(rows):
    seen, result = set(), []
    for row in rows:
        ident = row.get("id")
        if not ident or ident in seen:
            continue
        seen.add(ident)
        result.append(row)
    return result


def search_rows(source, query):
    query = query.strip()
    if not query:
        if source == "channels":
            return [page_row("channels:channels", "Subscriptions", "YouTube channels feed", "CHANNELS")]
        return [
            page_row("later:WL", "Watch later", "Private YouTube playlist", "WL"),
            page_row("history:history", "Watch history", "Signed-in YouTube history", "HISTORY"),
            page_row("channels:channels", "Subscriptions", "YouTube channels feed", "CHANNELS"),
        ]
    if not YOUTUBE.exists():
        return []
    rc, text, _ = run(["bash", YOUTUBE, "--ytsearch", source, query], timeout=20)
    return dedupe(parse_shared_rows(text))[:40] if rc == 0 or text else []


def unlink_quiet(path):
    try:
        path.unlink()
    except FileNotFoundError:
        pass
    except OSError:
        pass


def feed_rows(source, query, force=False):
    CACHE.mkdir(parents=True, exist_ok=True)
    cache_file = CACHE / ("quickshell-history.tsv" if source == "history" else "quickshell-watchlater.tsv")
    if force:
        unlink_quiet(cache_file)
    elif not query.strip() and cache_file.exists():
        try:
            if time.time() - cache_file.stat().st_mtime > 30:
                cache_file.unlink()
        except OSError:
            pass
    subcommand = "--ythistory" if source == "history" else "--ytwatchlater"
    rc, text, _ = run(["bash", YOUTUBE, subcommand, cache_file, query], timeout=45)
    return dedupe(parse_shared_rows(text)) if rc == 0 or text else []


def channel_base(target):
    target = clean(target)
    if target.startswith(("http://", "https://")):
        base = target
    elif target.startswith("@"):
        base = f"https://www.youtube.com/{target}"
    elif target:
        base = f"https://www.youtube.com/channel/{target}"
    else:
        return ""
    return re.sub(r"/(videos|streams)/?$", "", base.rstrip("/"))


def channel_rows(source, query, target, deep=False, force=False):
    base = channel_base(target)
    if not base:
        return []
    CACHE.mkdir(parents=True, exist_ok=True)
    tab = "streams" if source == "channel-streams" else "videos"
    limit = 2000 if deep and tab == "videos" else 40
    digest = hashlib.sha1(base.encode("utf-8")).hexdigest()[:16]
    suffix = "deep" if deep and tab == "videos" else tab
    cache_file = CACHE / f"quickshell-channel-{digest}.{suffix}.tsv"
    if force:
        unlink_quiet(cache_file)
    env = os.environ.copy()
    env["YOUTUBE_FZF_LIMIT"] = str(limit)
    rc, text, _ = run(
        ["bash", YOUTUBE, "--yttab", tab, base, cache_file],
        timeout=90 if deep else 35, env=env,
    )
    return filter_rows(parse_channel_rows(text), query) if rc == 0 or text else []


def list_rows(source, query="", target="", deep=False, force=False):
    if source in ("videos", "channels"):
        rows = search_rows(source, query)
    elif source in ("history", "later"):
        rows = feed_rows(source, query, force)
    elif source in ("channel-videos", "channel-streams"):
        rows = channel_rows(source, query, target, deep, force)
    else:
        rows = []
    return decorate_rows(rows, query)


def open_url(url):
    browser = os.environ.get("DOTFILES_BROWSER_BIN", "helium-browser")
    if not shutil.which("hyprctl") or not LIB.exists():
        try:
            subprocess.Popen([browser, url], stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            return True
        except Exception:
            return False
    script = r'''source "$1"
url="$2"
ws=4
if [[ -n "$(browser_window_off_workspace "$ws")" ]]; then
  open_in_new_browser_window "$url" "$ws"
else
  switch_to_workspace_for_browser "$ws"
  open_browser_url "$url"
  move_browser_when_up "$ws"
fi'''
    subprocess.Popen(["bash", "-lc", script, "_", str(LIB), url],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    return True


def open_ident(ident):
    record_usage(ident)
    if ident.startswith("video:"):
        return open_url("https://www.youtube.com/watch?v=" + ident.split(":", 1)[1])
    if ident.startswith("later:"):
        return open_url("https://www.youtube.com/playlist?list=WL")
    if ident.startswith("history:"):
        return open_url("https://www.youtube.com/feed/history")
    if ident.startswith("channels:"):
        return open_url("https://www.youtube.com/feed/channels")
    return False


def open_search(source, query):
    query = query.strip()
    if source == "history":
        return open_url("https://www.youtube.com/feed/history")
    if source == "later":
        return open_url("https://www.youtube.com/playlist?list=WL")
    encoded = urllib.parse.quote(query)
    suffix = "&sp=EgIQAg%3D%3D" if source == "channels" else ""
    return open_url(f"https://www.youtube.com/results?search_query={encoded}{suffix}")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "list":
        source = sys.argv[2] if len(sys.argv) > 2 else "videos"
        query = sys.argv[3] if len(sys.argv) > 3 else ""
        target = sys.argv[4] if len(sys.argv) > 4 else ""
        deep = len(sys.argv) > 5 and sys.argv[5] == "deep"
        force = len(sys.argv) > 6 and sys.argv[6] == "force"
        emit(list_rows(source, query, target, deep, force))
    elif command == "open":
        emit({"ok": bool(open_ident(sys.argv[2] if len(sys.argv) > 2 else ""))})
    elif command == "record":
        record_usage(sys.argv[2] if len(sys.argv) > 2 else "")
        emit({"ok": True})
    elif command == "open-search":
        source = sys.argv[2] if len(sys.argv) > 2 else "videos"
        query = sys.argv[3] if len(sys.argv) > 3 else ""
        emit({"ok": bool(open_search(source, query))})
    else:
        emit({"error": "unknown command"})


if __name__ == "__main__":
    main()
