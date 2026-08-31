#!/usr/bin/env python3
import hashlib
import json
import math
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, urlopen

HOME = Path.home()
# Resolve through ~/.config/quickshell when active, so this works from either
# main or the isolated worktree without hard-coding ~/github/dotfiles.
ROOT = Path(__file__).resolve().parent
DOTFILES = ROOT.parent
CACHE_DIR = HOME / ".cache/bookmarks-fzf"
BROWSER_BOOKMARKS_FILE = CACHE_DIR / "helium-bookmarks.tsv"
BROWSER_BOOKMARKS_FALLBACK = DOTFILES / "bookmarks/helium-bookmarks.tsv"
BROWSER_PROFILE_DIR = Path(
    os.path.expanduser(os.environ.get("DOTFILES_BROWSER_PROFILE_DIR", "~/.config/net.imput.helium/Default"))
)
BROWSER_BOOKMARKS_SOURCE = Path(
    os.path.expanduser(
        os.environ.get("DOTFILES_BROWSER_BOOKMARKS_SOURCE", str(BROWSER_PROFILE_DIR / "Bookmarks"))
    )
)
BROWSER_FAVICONS_DB = Path(
    os.path.expanduser(
        os.environ.get("DOTFILES_BROWSER_FAVICONS_DB", str(BROWSER_PROFILE_DIR / "Favicons"))
    )
)
BOOKMARK_FILES = [
    DOTFILES / "bookmarks/bookmarks.tsv",
    HOME / "dotfiles-private/bookmarks/bookmarks.tsv",
    BROWSER_BOOKMARKS_FILE,
    BROWSER_BOOKMARKS_FALLBACK,
]
RECENT_FILE = CACHE_DIR / "recent.tsv"
USAGE_FILE = CACHE_DIR / "usage.tsv"
FAVICON_DIR = CACHE_DIR / "favicons"
FAVICON_MISS_DIR = CACHE_DIR / "favicon-misses"
RECENT_MAX = 50
FREQUENCY_WEIGHT = float(os.environ.get("DOTFILES_BOOKMARK_FREQUENCY_WEIGHT", "0.65"))
NETWORK_TIMEOUT = 4
MAX_HTML_BYTES = 512 * 1024
MAX_ICON_BYTES = 1024 * 1024
MISS_RETRY_SECONDS = 24 * 60 * 60


def live_bookmarks():
    rows = []
    seen = set()
    for path in BOOKMARK_FILES:
        if not path.exists():
            continue
        try:
            for line in path.read_text(errors="ignore").splitlines():
                parts = line.split("\t", 1)
                if len(parts) != 2:
                    continue
                name, url = parts
                if not url or url in seen:
                    continue
                seen.add(url)
                rows.append({"name": name or url, "url": url})
        except OSError:
            pass
    return rows


def load_usage():
    counts = {}
    if not USAGE_FILE.exists():
        return counts
    try:
        for line in USAGE_FILE.read_text(errors="ignore").splitlines():
            parts = line.rsplit("\t", 1)
            if len(parts) != 2:
                continue
            url, raw_count = parts
            try:
                counts[url] = max(0, int(raw_count))
            except ValueError:
                pass
    except OSError:
        pass
    return counts


def record_usage(url: str):
    if not url:
        return
    counts = load_usage()
    counts[url] = counts.get(url, 0) + 1
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    ordered = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    USAGE_FILE.write_text("".join(f"{item_url}\t{count}\n" for item_url, count in ordered))


def favicon_path(url: str):
    if not url:
        return None
    return FAVICON_DIR / (hashlib.sha1(url.encode("utf-8")).hexdigest() + ".png")


def fuzzy_positions(text, query):
    """Character indices in `text` that satisfied `query`, for highlighting.

    Same scheme as quickshell/youtube-helper.py and picker-helper.py: a full
    substring match highlights contiguously, else each query character
    highlights the first place found scanning left to right.
    """
    value = str(text or "")
    hay = value.casefold()
    positions = set()
    for raw_term in str(query or "").casefold().split():
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


def decorate_rows(rows, usage=None, query=""):
    usage = load_usage() if usage is None else usage
    decorated = []
    for row in rows:
        item = dict(row)
        item["usage"] = usage.get(item.get("url", ""), 0)
        icon = favicon_path(item.get("url", ""))
        item["icon"] = icon.as_uri() if icon and icon.exists() else ""
        item["nameMatches"] = fuzzy_positions(item.get("name", ""), query)
        item["urlMatches"] = fuzzy_positions(item.get("url", ""), query)
        decorated.append(item)
    return decorated


def recent_bookmarks(rows=None):
    rows = live_bookmarks() if rows is None else rows
    if not RECENT_FILE.exists():
        return []
    by_url = {row["url"]: row for row in rows}
    ordered = []
    seen = set()
    try:
        for line in RECENT_FILE.read_text(errors="ignore").splitlines():
            parts = line.split("\t", 1)
            if len(parts) != 2:
                continue
            url = parts[1]
            if url in by_url and url not in seen:
                seen.add(url)
                ordered.append(by_url[url])
    except OSError:
        return []
    return ordered


def print_rows(rows):
    print(json.dumps(rows, ensure_ascii=False))


def _browser_rows(node, rows, seen):
    if isinstance(node, dict):
        url = str(node.get("url") or "")
        if node.get("type") == "url" and url.startswith("http") and url not in seen:
            seen.add(url)
            name = str(node.get("name") or url).replace("\t", " ").replace("\n", " ")
            rows.append((name, url))
        for value in node.values():
            _browser_rows(value, rows, seen)
    elif isinstance(node, list):
        for value in node:
            _browser_rows(value, rows, seen)


def _copy_sqlite_snapshot(source: Path, dest_dir: Path):
    if not source.exists():
        return None
    dest = dest_dir / source.name
    try:
        shutil.copy2(source, dest)
        wal = Path(str(source) + "-wal")
        shm = Path(str(source) + "-shm")
        if wal.exists():
            shutil.copy2(wal, Path(str(dest) + "-wal"))
        if shm.exists():
            shutil.copy2(shm, Path(str(dest) + "-shm"))
        return dest
    except OSError:
        return None


def _favicon_host(url: str):
    try:
        parsed = urlsplit(url)
    except ValueError:
        return ""
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        return ""
    # Ignore any userinfo but keep an explicit port and IPv6 brackets intact.
    return parsed.netloc.rsplit("@", 1)[-1].casefold()


def _sync_local_favicons(rows):
    if not BROWSER_FAVICONS_DB.exists() or not rows:
        return

    urls = list(dict.fromkeys(row["url"] for row in rows if row.get("url")))
    if not urls:
        return

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    FAVICON_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bookmarks-favicons-", dir=str(CACHE_DIR)) as tmp:
        snapshot = _copy_sqlite_snapshot(BROWSER_FAVICONS_DB, Path(tmp))
        if snapshot is None:
            return

        try:
            db = sqlite3.connect(f"file:{snapshot}?mode=ro", uri=True)
        except sqlite3.Error:
            return

        try:
            best = {}
            png_header = b"\x89PNG\r\n\x1a\n"
            # Prefer a mapping for the exact bookmark URL.
            for offset in range(0, len(urls), 300):
                chunk = urls[offset:offset + 300]
                placeholders = ",".join("?" for _ in chunk)
                query = f"""
                    SELECT m.page_url, b.image_data, b.width, b.height
                    FROM icon_mapping AS m
                    JOIN favicon_bitmaps AS b ON b.icon_id = m.icon_id
                    WHERE m.page_url IN ({placeholders})
                      AND b.image_data IS NOT NULL
                    ORDER BY b.width DESC, b.height DESC
                """
                try:
                    for page_url, image_data, width, height in db.execute(query, chunk):
                        if page_url in best or not image_data:
                            continue
                        data = bytes(image_data)
                        if data.startswith(png_header):
                            best[page_url] = data
                except sqlite3.Error:
                    return

            # Chromium often only has an icon mapping for another visited page
            # on the same site. Reuse that local favicon for bookmarks whose
            # exact URL has no mapping, without making a network request.
            by_host = {}
            for url in urls:
                host = _favicon_host(url)
                if host:
                    by_host.setdefault(host, []).append(url)

            host_query = """
                SELECT m.page_url, f.url, b.image_data, b.width, b.height
                FROM icon_mapping AS m
                JOIN favicons AS f ON f.id = m.icon_id
                JOIN favicon_bitmaps AS b ON b.icon_id = m.icon_id
                WHERE (
                    m.page_url = ? OR instr(m.page_url, ?) = 1 OR
                    m.page_url = ? OR instr(m.page_url, ?) = 1
                )
                  AND b.image_data IS NOT NULL
                -- Prefer a site's dark-theme asset when Chromium has both.
                -- The picker background is dark, and GitHub's default PNG is
                -- a black transparent mark that otherwise looks invisible.
                ORDER BY
                    CASE WHEN lower(f.url) LIKE '%dark%' THEN 0 ELSE 1 END,
                    b.width DESC, b.height DESC
            """
            for host, host_urls in by_host.items():
                https_base = f"https://{host}"
                http_base = f"http://{host}"
                try:
                    fallback = None
                    for page_url, _favicon_url, image_data, width, height in db.execute(
                        host_query,
                        (https_base, https_base + "/", http_base, http_base + "/"),
                    ):
                        if not image_data:
                            continue
                        data = bytes(image_data)
                        if data.startswith(png_header):
                            fallback = data
                            break
                except sqlite3.Error:
                    return
                if fallback is not None:
                    for url in host_urls:
                        best[url] = fallback

            for url, data in best.items():
                target = favicon_path(url)
                if target:
                    try:
                        target.write_bytes(data)
                    except OSError:
                        pass
        finally:
            db.close()


class _IconLinkParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        if tag.casefold() != "link":
            return
        values = {str(key).casefold(): str(value or "") for key, value in attrs}
        rel = values.get("rel", "").casefold().split()
        href = values.get("href", "")
        if href and "icon" in rel:
            self.urls.append(href)


def _read_url(url, limit, accept):
    request = Request(
        url,
        headers={
            "Accept": accept,
            "Accept-Encoding": "identity",
            "User-Agent": "dotfiles-bookmarks-favicon/1.0",
        },
    )
    with urlopen(request, timeout=NETWORK_TIMEOUT) as response:
        data = response.read(limit + 1)
        if len(data) > limit:
            return None, ""
        return data, response.headers.get_content_charset() or "utf-8"


def _valid_icon(data):
    if not data:
        return False
    signatures = (
        b"\x89PNG\r\n\x1a\n",
        b"\xff\xd8\xff",
        b"GIF87a",
        b"GIF89a",
        b"\x00\x00\x01\x00",
    )
    if any(data.startswith(signature) for signature in signatures):
        return True
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return True
    return b"<svg" in data[:1024].lstrip().casefold()


def _icon_format(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if data.startswith(b"\xff\xd8\xff"):
        return "jpeg"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "gif"
    if data.startswith(b"\x00\x00\x01\x00"):
        return "ico"
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "webp"
    if b"<svg" in data[:1024].lstrip().casefold():
        return "svg"
    return ""


def _as_png(data):
    source_format = _icon_format(data)
    if source_format == "png":
        return data
    magick = shutil.which("magick")
    if not source_format or not magick:
        return None
    try:
        converted = subprocess.run(
            [magick, f"{source_format}:-[0]", "png:-"],
            input=data,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=NETWORK_TIMEOUT,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if converted.returncode != 0 or not converted.stdout.startswith(b"\x89PNG\r\n\x1a\n"):
        return None
    return converted.stdout


def _download_favicon(page_url):
    try:
        html, charset = _read_url(page_url, MAX_HTML_BYTES, "text/html")
    except (HTTPError, URLError, OSError, ValueError):
        html, charset = None, "utf-8"

    candidates = []
    if html:
        parser = _IconLinkParser()
        try:
            parser.feed(html.decode(charset, errors="ignore"))
        except (LookupError, ValueError):
            parser.feed(html.decode("utf-8", errors="ignore"))
        candidates.extend(urljoin(page_url, href) for href in parser.urls)

    parsed = urlsplit(page_url)
    candidates.append(f"{parsed.scheme}://{parsed.netloc}/favicon.ico")
    for candidate in dict.fromkeys(candidates):
        if urlsplit(candidate).scheme not in ("http", "https"):
            continue
        try:
            data, _charset = _read_url(candidate, MAX_ICON_BYTES, "image/*")
        except (HTTPError, URLError, OSError, ValueError):
            continue
        if _valid_icon(data):
            png = _as_png(data)
            if png is not None:
                return png
    return None


def _miss_path(host):
    digest = hashlib.sha1(host.encode("utf-8")).hexdigest()
    return FAVICON_MISS_DIR / digest


def _miss_is_fresh(host):
    marker = _miss_path(host)
    try:
        return time.time() - marker.stat().st_mtime < MISS_RETRY_SECONDS
    except OSError:
        return False


def _sync_network_host(host, urls):
    if _miss_is_fresh(host):
        return
    data = _download_favicon(urls[0])
    if data is None:
        try:
            FAVICON_MISS_DIR.mkdir(parents=True, exist_ok=True)
            _miss_path(host).touch()
        except OSError:
            pass
        return
    for url in urls:
        target = favicon_path(url)
        try:
            target.write_bytes(data)
        except OSError:
            pass


def sync_favicons(rows):
    _sync_local_favicons(rows)
    missing_by_host = {}
    for row in rows:
        url = row.get("url", "")
        target = favicon_path(url)
        if not target or target.exists():
            continue
        host = _favicon_host(url)
        if host:
            missing_by_host.setdefault(host, []).append(url)
    if not missing_by_host:
        return
    FAVICON_DIR.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=min(6, len(missing_by_host))) as pool:
        futures = [
            pool.submit(_sync_network_host, host, urls)
            for host, urls in missing_by_host.items()
        ]
        for future in futures:
            try:
                future.result()
            except Exception:
                pass


def fetch_favicon(url):
    host = _favicon_host(url)
    if not host:
        return False
    FAVICON_DIR.mkdir(parents=True, exist_ok=True)
    _sync_network_host(host, [url])
    target = favicon_path(url)
    return bool(target and target.exists())


def sync_browser_bookmarks():
    # Equivalent catalog refresh to bookmarks.sh --sync-browser, but keep the
    # generated export in cache so opening the picker never dirties git.
    try:
        payload = json.loads(BROWSER_BOOKMARKS_SOURCE.read_text(errors="ignore"))
    except (OSError, json.JSONDecodeError):
        payload = None

    if payload is not None:
        rows = []
        _browser_rows(payload, rows, set())
        if rows:
            BROWSER_BOOKMARKS_FILE.parent.mkdir(parents=True, exist_ok=True)
            BROWSER_BOOKMARKS_FILE.write_text(
                "".join(f"{name}\t{url}\n" for name, url in rows)
            )

    # Extract icons once per picker open, not on every keystroke.
    sync_favicons(live_bookmarks())
    print("ok")


def weighted_fzf_rows(rows, query, usage):
    fzf = shutil.which("fzf")
    if not fzf:
        terms = query.casefold().split()
        filtered = [
            row for row in rows
            if all(term in (row["name"] + " " + row["url"]).casefold() for term in terms)
        ]
        indexed = list(enumerate(filtered))
        indexed.sort(
            key=lambda pair: pair[0]
            - FREQUENCY_WEIGHT * math.log2(usage.get(pair[1]["url"], 0) + 1)
        )
        return [row for _, row in indexed]

    # fzf still owns matching and the primary relevance order. Frequency is
    # applied only after fzf returns matches: logarithmic usage can move a
    # result a few nearby positions, but cannot make a poor match dominate.
    catalog = "".join(f"{row['name']}\t{row['url']}\n" for row in rows)
    result = subprocess.run(
        [fzf, "--filter", query, "--delimiter=\t"],
        input=catalog,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    ranked = []
    for fzf_rank, line in enumerate(result.stdout.splitlines()):
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        name, url = parts
        count = usage.get(url, 0)
        frequency_bonus = FREQUENCY_WEIGHT * math.log2(count + 1)
        ranked.append((fzf_rank - frequency_bonus, fzf_rank, {"name": name, "url": url}))

    ranked.sort(key=lambda item: (item[0], item[1]))
    return [row for _, _, row in ranked]


def search_bookmarks(query: str):
    rows = live_bookmarks()
    usage = load_usage()
    query = query.strip()

    if not query:
        # Keep the familiar empty state: recency first. Frequency is metadata
        # here and becomes a ranking bonus as soon as a query is typed.
        print_rows(decorate_rows(recent_bookmarks(rows), usage))
        return

    matched = weighted_fzf_rows(rows, query, usage)
    print_rows(decorate_rows(matched, usage, query))


def record_recent(name: str, url: str):
    if not url:
        return
    RECENT_FILE.parent.mkdir(parents=True, exist_ok=True)
    previous = []
    if RECENT_FILE.exists():
        try:
            previous = RECENT_FILE.read_text(errors="ignore").splitlines()
        except OSError:
            previous = []
    rows = [f"{name}\t{url}"]
    for line in previous:
        parts = line.split("\t", 1)
        if len(parts) == 2 and parts[1] != url:
            rows.append(line)
        if len(rows) >= RECENT_MAX:
            break
    RECENT_FILE.write_text("\n".join(rows) + "\n")


def open_bookmark(name: str, url: str):
    record_recent(name, url)
    record_usage(url)
    lib = DOTFILES / "scripts/lib.sh"
    script = 'source "$1"; open_or_focus_url "$2" 2 4 "$3"'
    subprocess.Popen(
        ["bash", "-lc", script, "bookmarks", str(lib), url, name],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "bookmarks"
    if action == "bookmarks":
        print_rows(decorate_rows(live_bookmarks()))
    elif action == "recent-bookmarks":
        print_rows(decorate_rows(recent_bookmarks()))
    elif action == "search-bookmarks":
        search_bookmarks(sys.argv[2] if len(sys.argv) >= 3 else "")
    elif action == "sync-bookmarks":
        sync_browser_bookmarks()
    elif action == "fetch-favicon" and len(sys.argv) >= 3:
        raise SystemExit(0 if fetch_favicon(sys.argv[2]) else 1)
    elif action == "open-bookmark" and len(sys.argv) >= 4:
        open_bookmark(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
