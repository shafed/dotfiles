#!/usr/bin/env python3
import importlib.util
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location(
    "dots_palette_helper", ROOT / "quickshell/palette-helper.py"
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot load quickshell/palette-helper.py")
HELPER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HELPER)


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    regular = root / "bookmarks.tsv"
    cache = root / "cache.tsv"
    fallback = root / "fallback.tsv"

    regular.write_text("Regular\thttps://regular.example\n")
    fallback.write_text("Deleted\thttps://deleted.example\n")

    HELPER.BOOKMARK_FILES = [regular]
    HELPER.BROWSER_BOOKMARKS_FILE = cache
    HELPER.BROWSER_BOOKMARKS_FALLBACK = fallback

    before_sync = {row["url"] for row in HELPER.live_bookmarks()}
    if "https://deleted.example" not in before_sync:
        raise SystemExit("browser fallback was not used before the cache existed")

    cache.write_text("Current\thttps://current.example\n")
    after_sync = {row["url"] for row in HELPER.live_bookmarks()}
    if after_sync != {"https://regular.example", "https://current.example"}:
        raise SystemExit(f"stale browser fallback remained after sync: {after_sync}")

print("palette-helper tests passed")
