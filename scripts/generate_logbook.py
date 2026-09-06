#!/usr/bin/env python3
"""Training Log HTML Generator.

Reads markdown session files from training/ and produces a single
self-contained logbook.html in the project root.

See spec.md for the full specification.
"""

from __future__ import annotations

import datetime as dt
import html
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import quote

TRAINING_DIR = Path(os.environ.get("LOGBOOK_ROOT", "~/github/obsidian/training")).expanduser()
# Written outside the vault so the generated artifact never pollutes/gets
# pushed by the vault's `git add -A` sync (see scripts/obsidian-sync.sh).
OUTPUT = (
    Path(os.environ.get("LOGBOOK_CACHE", "~/.cache/logbook")).expanduser()
    / "logbook.html"
)

FILENAME_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})-(?:Training|Day-\d+)$")
EVENT_LINE_RE = re.compile(
    r"^(?:[-*]\s+)?(\d{4}-\d{2}-\d{2}):\s*#(bad|neutral|good)\b\s*(.*)$", re.I
)
# Looks like an event start ("YYYY-MM-DD: ...") but failed the tag check.
EVENT_MAYBE_RE = re.compile(r"^(?:[-*]\s+)?\d{4}-\d{2}-\d{2}:\s*\S")
EVENTS_FILE = "events.md"
# Non-session markdown files that should be ignored by the session scan without
# a warning (events + hand-kept aggregates).
SKIP_FILES = {"events.md", "training.md"}
SKIP_DIR_PARTS = {"_templates", "_import"}
# Session mood lives in the file's YAML frontmatter: "mood: mid" / "mood: bad".
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n?", re.S)
MOOD_FM_RE = re.compile(r"^mood:\s*(bad|mid|great)\s*$", re.I | re.M)
WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


# --------------------------------------------------------------------------- #
# Data model
# --------------------------------------------------------------------------- #
@dataclass
class Exercise:
    code: str  # e.g. "1A" ("" if absent)
    name: str
    reps: str
    weight: str
    notes: list[str] = field(default_factory=list)  # raw markdown note lines

    @property
    def group(self) -> str:
        """Superset group = leading digits of the code ("1A" -> "1")."""
        m = re.match(r"\d+", self.code)
        return m.group(0) if m else ""


@dataclass
class Session:
    date: dt.date
    path: Path
    exercises: list[Exercise] = field(default_factory=list)
    general_notes: list[str] = field(default_factory=list)  # raw markdown
    extra_sections: list[tuple[str, str]] = field(
        default_factory=list
    )  # (title, raw md body)
    mood: str | None = None  # "bad" | "mid" | "great" | None

    @property
    def weekday(self) -> str:
        return WEEKDAYS[self.date.weekday()]

    @property
    def label(self) -> str:
        return f"{self.date.isoformat()} ({self.weekday})"

    @property
    def program(self) -> str:
        """Training program = the sheet folder the session lives in.

        Files directly in training/ (not in a sheet subfolder) report "".
        """
        try:
            rel = self.path.parent.relative_to(TRAINING_DIR)
        except ValueError:
            return ""
        parts = rel.parts
        return parts[0] if parts else ""


@dataclass
class Event:
    date: dt.date
    tag: str  # "bad" | "neutral" | "good"
    text: str


# --------------------------------------------------------------------------- #
# Parsing
# --------------------------------------------------------------------------- #
def parse_reps(raw: str) -> str:
    """Apply spec reps rules.

    - if there is a comma -> drop the "Nx" prefix ("3x8,6,6" -> "8,6,6")
    - otherwise keep verbatim ("3x12" -> "3x12")
    """
    raw = raw.strip()
    if not raw:
        return raw
    raw = re.sub(r"\s+", "", raw)
    raw = raw.replace("X", "x").replace("х", "x").replace("Х", "x").replace("×", "x")
    if "," in raw:
        return re.sub(r"^\d+x", "", raw)
    return raw


def parse_table(lines: list[str]) -> list[Exercise]:
    """Parse the first 4-column exercise table found in *lines*.

    Returns [] if no usable table is present.
    """
    rows: list[list[str]] = []
    for line in lines:
        s = line.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        rows.append(cells)

    # Drop separator rows like | --- | --- | ... |
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    if len(rows) < 2:
        return []

    header = [c.lower() for c in rows[0]]
    # Expect a header containing #, exercise, reps, weight
    try:
        i_code = header.index("#")
        i_name = header.index("exercise")
        i_reps = header.index("reps")
        i_weight = header.index("weight")
    except ValueError:
        return []

    exercises: list[Exercise] = []
    for r in rows[1:]:
        if len(r) <= max(i_code, i_name, i_reps, i_weight):
            continue
        name = r[i_name].strip()
        if not name:
            continue
        exercises.append(
            Exercise(
                code=r[i_code].strip(),
                name=name,
                reps=parse_reps(r[i_reps]),
                weight=r[i_weight].strip(),
            )
        )
    return exercises


def split_note_blocks(lines: list[str]) -> list[str]:
    """Group a markdown bullet list into top-level note blocks.

    Each returned string is a top-level "- ..." item together with its
    nested children (preserved as raw markdown so it can be rendered later).
    """
    blocks: list[str] = []
    cur: list[str] = []
    for line in lines:
        if re.match(r"^-\s", line):  # new top-level bullet
            if cur:
                blocks.append("\n".join(cur))
            cur = [line]
        else:
            # Keep any preamble content instead of silently dropping it.
            # This preserves paragraphs, "*", numbered lists, and indented
            # bullets that appear before the first top-level "- " item.
            if cur or line.strip() != "":
                cur.append(line)
    if cur:
        blocks.append("\n".join(cur))
    return blocks


def match_note_to_exercise(block: str, exercises: list[Exercise]) -> Exercise | None:
    """Fuzzy-match a note block to an exercise (by code or name)."""
    # The "key" of the note is the text before the first ":" on the first line,
    # falling back to the whole first line.
    first = block.splitlines()[0]
    first = re.sub(r"^-\s*", "", first).strip()
    key = first.split(":", 1)[0].strip() if ":" in first else first
    key_l = key.lower()

    if not key_l:
        return None

    # 1) exact code match (case-insensitive): "2a" == "2A"
    for ex in exercises:
        if ex.code and ex.code.lower() == key_l:
            return ex

    # 2) exact name match first, then only accept a partial match when it is
    # unambiguous.  This avoids attaching "row" to the wrong exercise.
    exact_name = [ex for ex in exercises if ex.name.lower() == key_l]
    if len(exact_name) == 1:
        return exact_name[0]

    candidates = []
    for ex in exercises:
        nl = ex.name.lower()
        if nl and (nl in key_l or key_l in nl):
            candidates.append(ex)
    if len(candidates) == 1:
        return candidates[0]
    return None


def parse_session(path: Path) -> Session | None:
    stem = path.stem
    m = FILENAME_RE.match(stem)
    if not m:
        print(
            f"WARNING: skipping {path.name}: filename has no valid date",
            file=sys.stderr,
        )
        return None
    try:
        date = dt.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except ValueError:
        print(
            f"WARNING: skipping {path.name}: invalid date in filename", file=sys.stderr
        )
        return None

    text = path.read_text(encoding="utf-8")
    mood = None
    fm = FRONTMATTER_RE.match(text)
    if fm:
        mm = MOOD_FM_RE.search(fm.group(1))
        if mm:
            mood = mm.group(1).lower()
        text = text[fm.end() :]
    lines = text.split("\n")

    exercises = parse_table(lines)
    if not exercises:
        print(
            f"WARNING: skipping {path.name}: no valid exercise table", file=sys.stderr
        )
        return None

    session = Session(date=date, path=path, exercises=exercises, mood=mood)

    # Carve the document into regions.
    # Everything after the table that is a top-level list before the first
    # "### " heading is treated as notes; "### "/non-list content -> sections.
    table_end = 0
    for i, line in enumerate(lines):
        if line.strip().startswith("|"):
            table_end = i
    body = lines[table_end + 1 :]

    # Separate extra "### " sections (and the leading link line) out.
    note_lines: list[str] = []
    extra_lines: list[str] = []
    in_section = False
    cur_title = None
    cur_body: list[str] = []

    def flush_section():
        nonlocal cur_title, cur_body
        if cur_title is not None:
            session.extra_sections.append((cur_title, "\n".join(cur_body).strip()))
        cur_title, cur_body = None, []

    for line in body:
        if line.startswith("### "):
            flush_section()
            in_section = True
            cur_title = line[4:].strip()
            cur_body = []
            continue
        if in_section:
            cur_body.append(line)
        else:
            note_lines.append(line)
    flush_section()

    # Drop the "Training Log" link (and any standalone markdown-link bullet);
    # these are not real notes and are not rendered.
    real_notes: list[str] = []
    for line in note_lines:
        if re.match(r"^-\s*\[.*\]\(.*\)\s*$", line.strip()):
            continue
        real_notes.append(line)

    # Distribute note blocks between exercises and general notes.
    for block in split_note_blocks(real_notes):
        ex = match_note_to_exercise(block, exercises)
        if ex is not None:
            ex.notes.append(block)
        else:
            session.general_notes.append(block)

    return session


def parse_events(path: Path) -> list[Event]:
    """Parse ``training/events.md`` into a list of timeline Events.

    An event starts with ``YYYY-MM-DD: #bad|#neutral|#good text``; headings and
    empty lines are ignored. Prettier hard-wraps long lines, so a non-empty,
    non-heading line that does not start a new event continues the previous
    event's text on a new line (kept as "\n" and rendered as <br>; a blank line
    ends the block). The order of events on the same date follows the file order.
    """
    if not path.is_file():
        return []
    events: list[Event] = []
    cur: Event | None = None
    for raw in path.read_text(encoding="utf-8").split("\n"):
        line = raw.strip()
        m = EVENT_LINE_RE.match(line)
        if m:
            try:
                date = dt.date.fromisoformat(m.group(1))
            except ValueError:
                print(
                    f"WARNING: {path.name}: bad event date in {line!r}", file=sys.stderr
                )
                cur = None
                continue
            cur = Event(date=date, tag=m.group(2).lower(), text=m.group(3).strip())
            events.append(cur)
            continue
        if not line:
            cur = None  # blank line ends a wrapped event
            continue
        if line.startswith("#"):
            continue  # heading
        if EVENT_MAYBE_RE.match(line):
            # Date + unknown/missing tag -> not glued to the previous event.
            print(
                f"WARNING: {path.name}: ignored malformed event {line!r}",
                file=sys.stderr,
            )
            cur = None
            continue
        if cur is not None:
            # prettier hard-wrapped continuation -> keep the break visible
            cur.text = line if not cur.text else f"{cur.text}\n{line}"
    return events


# --------------------------------------------------------------------------- #
# Minimal markdown -> HTML (inline + nested lists)
# --------------------------------------------------------------------------- #
def md_inline(text: str) -> str:
    """Render inline markdown: escape, then bold/italic/code."""
    out = html.escape(text)
    # inline code
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    # bold
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"__([^_]+)__", r"<strong>\1</strong>", out)
    # italic
    out = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", out)
    out = re.sub(r"(?<![\w_])_([^_\n]+)_(?![\w_])", r"<em>\1</em>", out)
    # links
    out = re.sub(
        r"\[([^\]]+)\]\(((?:[^()]|\([^()]*\))*)\)",
        r'<a href="\2" target="_blank" rel="noopener">\1</a>',
        out,
    )
    return out


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def md_block(text: str) -> str:
    """Render a markdown note block (a top-level bullet + nested children)."""
    raw = [l for l in text.split("\n") if l.strip() != ""]
    if not raw:
        return ""

    # Build nested <ul> from indentation of "- " / "1. " items.
    def is_item(l: str) -> bool:
        s = l.lstrip(" ")
        return bool(re.match(r"^(-|\*|\d+\.)\s", s))

    def item_text(l: str) -> str:
        s = l.lstrip(" ")
        return re.sub(r"^(-|\*|\d+\.)\s+", "", s)

    if not is_item(raw[0]):
        # plain paragraph(s)
        return "<p>" + "<br>".join(md_inline(l.strip()) for l in raw) + "</p>"

    html_out: list[str] = []
    stack: list[int] = []  # indentation levels with open <ul>/<li> pairs

    for line in raw:
        if not is_item(line):
            # continuation text -> append to current li
            html_out.append(" " + md_inline(line.strip()))
            continue
        ind = _indent(line)
        if not stack:
            html_out.append("<ul>")
            stack.append(ind)
            html_out.append("<li>" + md_inline(item_text(line)))
            continue

        if ind > stack[-1]:
            # Open a nested list inside the currently open <li>.
            html_out.append("<ul>")
            stack.append(ind)
        elif ind == stack[-1]:
            html_out.append("</li>")
        else:
            html_out.append("</li>")
            while len(stack) > 1 and ind < stack[-1]:
                html_out.append("</ul>")
                stack.pop()
                html_out.append("</li>")

        html_out.append("<li>" + md_inline(item_text(line)))

    if stack:
        html_out.append("</li>")
    while len(stack) > 1:
        html_out.append("</ul>")
        stack.pop()
        html_out.append("</li>")
    if stack:
        html_out.append("</ul>")

    return "".join(html_out)


# --------------------------------------------------------------------------- #
# HTML rendering
# --------------------------------------------------------------------------- #
def render_exercise_cell(ex: Exercise) -> str:
    name = html.escape(ex.name)
    code = html.escape(ex.code)
    reps = html.escape(ex.reps)
    weight = html.escape(ex.weight)
    notes_html = ""
    if ex.notes:
        notes_html = (
            '<div class="exnotes">'
            + "".join(f'<div class="exnote">{md_block(n)}</div>' for n in ex.notes)
            + "</div>"
        )
    code_html = f'<span class="excode">{code}</span>' if code else ""
    return (
        '<div class="exline">'
        f"{code_html}"
        f'<button class="exname" data-ex="{html.escape(ex.name, quote=True)}">{name}</button>'
        f'<span class="exreps">{reps}</span>'
        f'<span class="exweight">{weight}</span>'
        "</div>"
        f"{notes_html}"
    )


def render_session(s: Session) -> str:
    # Group exercises into superset blocks by group digit; consecutive rows
    # with the same non-empty group form one block.
    blocks: list[list[Exercise]] = []
    for ex in s.exercises:
        if blocks and ex.group and ex.group == blocks[-1][0].group:
            blocks[-1].append(ex)
        else:
            blocks.append([ex])

    ex_html_parts = []
    for block in blocks:
        cls = "exblock superset" if len(block) > 1 else "exblock"
        inner = "".join(render_exercise_cell(ex) for ex in block)
        ex_html_parts.append(f'<div class="{cls}">{inner}</div>')
    ex_html = "".join(ex_html_parts)

    gen_html = ""
    if s.general_notes:
        gen_html = (
            '<div class="gennotes">'
            + "".join(
                f'<div class="gennote">{md_block(n)}</div>' for n in s.general_notes
            )
            + "</div>"
        )

    extras_html = ""
    for title, bodytext in s.extra_sections:
        if not bodytext.strip():
            continue
        extras_html += (
            '<details class="extra"><summary>'
            f"{html.escape(title)}</summary>"
            f'<div class="extrabody">{md_block(bodytext)}</div>'
            "</details>"
        )

    # nvim-edit:// link -> opens the source file in nvim inside the kitty
    # obsidian session via ~/github/dotfiles/scripts/nvim-edit-handler.sh. Path is percent-encoded.
    edit_uri = "nvim-edit://" + quote(str(s.path.resolve()))
    mood_class = f" mood-{s.mood}" if s.mood else ""
    mood_badge = (
        f'<span class="mood-tag mood-tag-{s.mood}">{s.mood}</span>' if s.mood else ""
    )
    return (
        f'<article class="day{mood_class}" data-date="{s.date.isoformat()}" '
        f'data-year="{s.date.year}" data-month="{s.date.month:02d}" '
        f'data-program="{html.escape(s.program, quote=True)}">'
        f'<h3><a class="srclink" href="{html.escape(edit_uri, quote=True)}" '
        f'title="Open in obsidian nvim">{html.escape(s.label)}</a>'
        f"{mood_badge}"
        "</h3>"
        f'<div class="exlist">{ex_html}</div>'
        f"{gen_html}"
        f"{extras_html}"
        "</article>"
    )


def render_event(e: Event) -> str:
    # hard newlines in the source (e.g. prettier wraps) stay visible
    body = "<br>".join(md_inline(line) for line in e.text.split("\n"))
    return (
        f'<article class="event event-{e.tag}" data-date="{e.date.isoformat()}" '
        f'data-year="{e.date.year}" data-month="{e.date.month:02d}">'
        f"<time>{e.date.isoformat()}</time>"
        f'<span class="event-tag">{html.escape(e.tag)}</span>'
        f'<span class="event-body">{body}</span>'
        "</article>"
    )


def build_exercise_index(sessions: list[Session]) -> dict:
    """exercise name -> list of appearances (newest first)."""
    index: dict[str, list[dict]] = {}
    for s in sessions:  # sessions already newest-first
        edit_uri = "nvim-edit://" + quote(str(s.path.resolve()))
        for ex in s.exercises:
            index.setdefault(ex.name, []).append(
                {
                    "date": s.date.isoformat(),
                    "label": s.label,
                    "reps": ex.reps,
                    "weight": ex.weight,
                    "notes": [md_block(n) for n in ex.notes],
                    "href": edit_uri,
                }
            )
    return index


def render_program_filter(sessions: list[Session]) -> str:
    """Buttons to filter the feed by training program (sheet folder).

    Programs are ordered newest-first by their latest session date.
    """
    latest: dict[str, dt.date] = {}
    for s in sessions:
        prog = s.program
        if not prog:
            continue
        if prog not in latest or s.date > latest[prog]:
            latest[prog] = s.date
    if not latest:
        return ""
    order = sorted(latest, key=lambda p: latest[p], reverse=True)
    parts = [
        '<button class="pf pf-all" data-program="all" aria-selected="true">'
        "All programs</button>"
    ]
    for prog in order:
        parts.append(
            f'<button class="pf" data-program="{html.escape(prog, quote=True)}">'
            f"{html.escape(prog)}</button>"
        )
    return '<div class="programfilter">' + "".join(parts) + "</div>"


# --------------------------------------------------------------------------- #
# Page assembly
# --------------------------------------------------------------------------- #
CSS = """
:root{
  --ink:#1c1b19; --soft:#6b6862; --line:#e0ddd4; --paper:#f7f5ef;
  --panel:#fffefb; --accent:#b4541f; --grid-alt:#f1eee6; --mark:#fff1b8;
}
@media (prefers-color-scheme:dark){
  :root{
    --ink:#e8e5dd; --soft:#9a968c; --line:#33312b; --paper:#16150f;
    --panel:#1d1c16; --accent:#9b6fd4; --grid-alt:#23221b; --mark:#5b4a16;
  }
}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);
  font:15px/1.5 'Iosevka','SF Mono',ui-monospace,Menlo,monospace;
  -webkit-font-smoothing:antialiased}
.wrap{max-width:1180px;margin:0 auto;padding:26px 16px 90px}
header.top{border-bottom:2px solid var(--ink);padding-bottom:12px;margin-bottom:14px}
h1{font:600 26px/1 'Georgia',serif;letter-spacing:-.01em;margin:0 0 6px}
.meta{color:var(--soft);font-size:12px;letter-spacing:.04em}

.controls{position:sticky;top:0;z-index:5;background:var(--paper);
  padding:10px 0;margin-bottom:8px;border-bottom:1px solid var(--line)}
.searchwrap{position:relative;display:flex;align-items:center}
.searchicon{position:absolute;left:14px;width:16px;height:16px;color:var(--soft);
  pointer-events:none}
#search{width:100%;font:inherit;font-size:14px;padding:11px 44px 11px 40px;
  border-radius:9px;border:1px solid var(--line);background:var(--panel);
  color:var(--ink);transition:border-color .15s,box-shadow .15s}
#search::placeholder{color:var(--soft)}
#search:hover{border-color:var(--soft)}
#search:focus{outline:none;border-color:var(--accent);
  box-shadow:0 0 0 3px color-mix(in srgb,var(--accent) 22%,transparent)}
/* kill the native type=search clear icon (webkit/Chromium mobile) so it
   doesn't double up with our own .searchclear button */
#search::-webkit-search-cancel-button,
#search::-webkit-search-decoration{-webkit-appearance:none;appearance:none;display:none}
.searchkbd{position:absolute;right:12px;font:500 11px/1 'Iosevka',ui-monospace,monospace;
  color:var(--soft);border:1px solid var(--line);background:var(--grid-alt);
  border-radius:5px;padding:3px 6px;pointer-events:none}
.searchwrap:focus-within .searchkbd{display:none}
.searchclear{display:none;position:absolute;right:10px;width:22px;height:22px;
  align-items:center;justify-content:center;appearance:none;border:0;background:none;
  color:var(--soft);font-size:18px;line-height:1;cursor:pointer;border-radius:5px}
.searchclear:hover{color:var(--ink);background:var(--grid-alt)}
.searchwrap.has-value .searchclear{display:flex}
.searchwrap.has-value .searchkbd{display:none}

.tabs{display:flex;gap:2px;margin:12px 0 6px;border-bottom:1px solid var(--line)}
.tab{appearance:none;border:0;background:none;font:inherit;font-size:13px;
  padding:8px 14px;cursor:pointer;color:var(--soft);border-bottom:2px solid transparent;
  margin-bottom:-1px;letter-spacing:.03em}
.tab[aria-selected=true]{color:var(--ink);border-color:var(--accent);font-weight:600}
.view{display:none} .view.active{display:block}
h2.eye{font:600 11px/1 inherit;text-transform:uppercase;letter-spacing:.18em;
  color:var(--accent);margin:14px 0 14px}

/* program filter */
.programfilter{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 16px}
.pf,.pf-all{appearance:none;border:1px solid var(--line);background:var(--panel);
  font:inherit;font-size:12px;padding:5px 11px;border-radius:6px;cursor:pointer;color:var(--soft)}
.pf[aria-selected=true],.pf-all[aria-selected=true]{
  background:var(--accent);border-color:var(--accent);color:#fff;font-weight:600}

/* session card */
.day{background:var(--panel);border:1px solid var(--line);border-radius:8px;
  padding:14px 16px;margin-bottom:14px}
.day.hidden{display:none}
.day h3{font:600 16px/1.2 'Georgia',serif;margin:0 0 12px;display:flex;
  align-items:baseline;gap:12px;flex-wrap:wrap}
.srclink{color:inherit;text-decoration:none;border-bottom:1px dotted transparent}
.srclink:hover{color:var(--accent);border-bottom-color:var(--accent)}

.exlist{display:flex;flex-direction:column;gap:8px}
.exblock{padding:2px 0}
.exblock.superset{border-left:3px solid var(--accent);padding-left:10px;
  background:var(--grid-alt);border-radius:0 5px 5px 0}
.exline{display:grid;grid-template-columns:minmax(24px,auto) minmax(0,1fr) 88px 112px;
  align-items:baseline;column-gap:8px;padding:4px 12px 4px 0}
.excode{flex:0 0 auto;font-size:11px;color:var(--soft);min-width:24px}
.exname{appearance:none;border:0;background:none;font:600 14px/1.2 'Georgia',serif;
  color:var(--ink);cursor:pointer;padding:0;text-align:left;min-width:0;
  border-bottom:1px dotted transparent}
.exname:hover{color:var(--accent);border-bottom-color:var(--accent)}
.exreps{font-size:13px;color:var(--soft);text-align:center;white-space:nowrap}
.exweight{font-size:13px;font-weight:600;text-align:center;white-space:nowrap}
.exnotes{margin:2px 0 4px 32px;display:flex;flex-direction:column;gap:3px}
.exnote{font-size:12.5px;color:var(--ink);background:var(--grid-alt);padding:4px 9px;
  border-radius:5px}
.exnote ul{margin:2px 0;padding-left:18px} .exnote p{margin:0}
.exnote a{color:var(--accent);word-break:break-all}

.gennotes{margin-top:12px;display:flex;flex-direction:column;gap:4px;
  border-top:1px dotted var(--line);padding-top:10px}
.gennote{font-size:13px}
.gennote ul{margin:2px 0;padding-left:18px} .gennote p{margin:0}
.gennote a{color:var(--accent);word-break:break-all}
/* session mood: tints the whole session card + a small text badge in the
   heading (visible in the UI and matchable by search) */
.day.mood-bad{background:#fbe6e3}
.day.mood-mid{background:#fbf2df}
.day.mood-great{background:#e6f3ec}
@media (prefers-color-scheme:dark){
  .day.mood-bad{background:#3a211e}
  .day.mood-mid{background:#332b18}
  .day.mood-great{background:#1d3126}
}
.mood-tag{display:inline-block;font-size:11px;font-weight:700;
  text-transform:uppercase;letter-spacing:.04em;padding:2px 7px;
  border-radius:4px;color:#fff}
.mood-tag-bad{background:#b84a4a}
.mood-tag-mid{background:#b89a38}
.mood-tag-great{background:#3f8f68}

details.extra{margin-top:10px;border-top:1px dotted var(--line);padding-top:8px}
details.extra summary{cursor:pointer;font-size:12px;color:var(--accent);
  text-transform:uppercase;letter-spacing:.1em;font-weight:600}
.extrabody{margin-top:8px;font-size:13px;color:var(--ink)}
.extrabody ul,.extrabody ol{padding-left:20px} .extrabody p{margin:6px 0}
.extrabody a{color:var(--accent);word-break:break-all}

/* exercise history view */
.exfilter{margin-bottom:14px;color:var(--soft);font-size:13px}
.exfilter a{color:var(--accent);cursor:pointer}
.exitem{background:var(--panel);border:1px solid var(--line);border-radius:8px;
  padding:12px 16px;margin-bottom:12px}
.exitem.hidden{display:none}
.exitem h3{font:600 16px/1.2 'Georgia',serif;margin:0 0 10px}
.exhist .exrow{padding:7px 0;border-bottom:1px dotted var(--line)}
.exhist .exrow:last-child{border-bottom:0}
.exhdate{display:inline-block;width:130px;color:var(--soft);font-size:12px;
  text-decoration:none;border-bottom:1px dotted transparent}
.exhdate:hover{color:var(--accent);border-bottom-color:var(--accent)}
.exhnums{font-size:13px}
.exhnums b{font-weight:600}
.exhnotes{margin:4px 0 1px 16px;display:flex;flex-direction:column;gap:3px}
.exhnote{font-size:12.5px;color:var(--ink);background:var(--grid-alt);
  padding:4px 9px;border-radius:5px}
.exhnote ul{margin:2px 0;padding-left:18px} .exhnote p{margin:0}
.exhnote a{color:var(--accent);word-break:break-all}

.exall{columns:2 200px;column-gap:14px}
.exall a{display:block;color:var(--ink);text-decoration:none;padding:5px 0;
  border-bottom:1px dotted var(--line);cursor:pointer;break-inside:avoid}
.exall a:hover{color:var(--accent)}
.exall a.hidden{display:none}
.exall .cnt{color:var(--soft);font-size:11px}

/* timeline events */
.event{margin:8px 0 14px;padding:8px 12px;
  color:var(--ink);background:var(--grid-alt);border-radius:5px;
  display:flex;align-items:baseline;flex-wrap:wrap;gap:2px 0}
.event.hidden{display:none}
.event time{color:var(--soft);font-size:12px;margin-right:8px}
.event-tag{display:inline-block;margin-right:8px;font-size:11px;font-weight:600;
  text-transform:uppercase;letter-spacing:.04em}
.event-body{font-size:13px}
.event-bad{background:#fbe6e3}
.event-bad .event-tag{color:#9d3535}
.event-neutral{background:#eceae4}
.event-neutral .event-tag{color:var(--soft)}
.event-good{background:#e6f3ec}
.event-good .event-tag{color:#3f8f68}
@media (prefers-color-scheme:dark){
  .event-bad{background:#3a211e}
  .event-neutral{background:#2a2922}
  .event-good{background:#1d3126}
}

mark{background:var(--mark);color:inherit;border-radius:2px;padding:0 1px}
.empty{color:var(--soft);text-align:center;padding:40px 0}
"""

JS = """
const sessions=[...document.querySelectorAll('#feed .day, #feed .event')];
const feedList=document.getElementById('feedlist');
const exData=__EXDATA__;
let highlightedRows=[];
let searchTimer=0;
let highlightTimer=0;

/* tab switching */
const tabs=[...document.querySelectorAll('.tab')];
function showView(id){
  tabs.forEach(t=>t.setAttribute('aria-selected',t.dataset.v===id));
  document.querySelectorAll('.view').forEach(v=>v.classList.toggle('active',v.id===id));
  // The search box is shared across both tabs -> whichever view you land on
  // must reflect its current value immediately, even if it was last typed
  // while the other tab was showing. A background sync only, so it leaves
  // an already-open exercise detail alone.
  if(id==='feed') runSearch(searchBox.value);
  else if(id==='exercise') filterExercises(searchBox.value);
}
tabs.forEach(t=>t.addEventListener('click',()=>showView(t.dataset.v)));

/* ---- program filter (feed) ---- */
let curProgram='all';
const pfBtns=[...document.querySelectorAll('.pf,.pf-all')];
function applyFilter(){
  sessions.forEach(s=>{
    let show=true;
    if(curProgram!=='all'){
      // events carry no program -> hidden while a specific program is selected
      show = s.dataset.program===curProgram;
    }
    s.classList.toggle('hidden',!show);
  });
}
function setFilterSelected(){
  pfBtns.forEach(b=>b.setAttribute('aria-selected', b.dataset.program===curProgram));
}
pfBtns.forEach(b=>b.addEventListener('click',()=>{
  if(searchBox.value){ searchBox.value=''; updateSearchClear(); cancelDeferredWork(); runSearch(''); }
  curProgram = b.dataset.program;
  setFilterSelected(); applyFilter();
}));

/* ---- search ---- */
const searchBox=document.getElementById('search');
function clearMarks(root){
  root.querySelectorAll('mark').forEach(m=>{
    const t=document.createTextNode(m.textContent); m.replaceWith(t);
  });
  root.normalize();
}
function normSearch(s){
  return (s||'').toLowerCase().normalize('NFKD').replace(/[\\u0300-\\u036f]/g,'').replace(/ё/g,'е');
}
function normSearchWords(s){
  return normSearch(s).replace(/[^\\p{L}\\p{N}]+/gu,' ').trim().replace(/\\s+/g,' ');
}
const searchRows=sessions.map((el,order)=>{
  const text=el.textContent;
  const hay=normSearch(text);
  const hayWords=normSearchWords(text);
  const words=hayWords.split(' ').filter(Boolean);
  const dateWords=normSearchWords(el.dataset.date||'');
  return {el,order,hay,hayWords,words,dateWords,dateTokens:dateWords.split(' ').filter(Boolean)};
});
function restoreFeedOrder(){
  searchRows.forEach(r=>feedList.appendChild(r.el));
}
function fuzzyToken(text, token){
  if(!token) return true;
  if(text.includes(token)) return true;
  let j=0;
  for(let i=0;i<text.length&&j<token.length;i++){
    if(text[i]===token[j]) j++;
  }
  return j===token.length;
}
function fuzzyMatch(row, queryWords, tokens){
  // Fuzzy-matches each token against individual words, not the whole card's
  // text glued together -> a short query no longer subsequence-matches
  // across unrelated exercise names/reps/dates just by chance.
  if(!queryWords) return false;
  if(row.hayWords.includes(queryWords)) return true;
  return tokens.length>0 && tokens.every(t=>row.words.some(w=>fuzzyToken(w,t)));
}
function searchScore(row, queryWords, tokens){
  let score=0;
  if(row.dateWords===queryWords) score+=10000;
  else if(row.dateWords.includes(queryWords)) score+=8000;
  if(row.hayWords.includes(queryWords)) score+=1000;
  tokens.forEach(t=>{
    if(row.dateTokens.includes(t)) score+=150;
    else if(row.hay.includes(t)) score+=25;
    else if(fuzzyToken(row.hay,t)) score+=5;
  });
  return score;
}
function highlight(root,q){
  if(!q) return;
  const tokens=q.trim().split(/\\s+/).filter(Boolean).map(t=>t.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&'));
  if(!tokens.length) return;
  const re=new RegExp(tokens.join('|'),'gi');
  const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT,{
    acceptNode:n=>n.parentNode.closest('script,style')?NodeFilter.FILTER_REJECT
      :(re.test(n.nodeValue)?NodeFilter.FILTER_ACCEPT:NodeFilter.FILTER_REJECT)
  });
  const nodes=[]; while(walker.nextNode()) nodes.push(walker.currentNode);
  nodes.forEach(n=>{
    const span=document.createElement('span');
    span.innerHTML=n.nodeValue.replace(re,m=>'<mark>'+m+'</mark>');
    n.replaceWith(span);
  });
}
function cancelDeferredWork(){
  if(searchTimer){ clearTimeout(searchTimer); searchTimer=0; }
  if(highlightTimer){ clearTimeout(highlightTimer); highlightTimer=0; }
}
function scheduleHighlight(rows,q){
  if(highlightTimer) clearTimeout(highlightTimer);
  highlightTimer=setTimeout(()=>{
    highlightTimer=0;
    highlightedRows=rows;
    highlightedRows.forEach(s=>highlight(s,q));
  },0);
}
function runSearch(q){
  q=q.trim();
  if(highlightTimer){ clearTimeout(highlightTimer); highlightTimer=0; }
  highlightedRows.forEach(clearMarks);
  highlightedRows=[];
  if(q){
    // search overrides the program filter. (Every caller already has the
    // feed view active or is showView() itself switching into it -- calling
    // showView('feed') here too would recurse back into runSearch.)
    curProgram='all'; setFilterSelected();
    const queryWords=normSearchWords(q);
    const tokens=queryWords.split(/\\s+/).filter(Boolean);
    const hits=[];
    searchRows.forEach(r=>{
      const hit=fuzzyMatch(r,queryWords,tokens);
      r.el.classList.toggle('hidden',!hit);
      if(hit){
        hits.push([searchScore(r,queryWords,tokens), r.order, r.el]);
      }
    });
    hits.sort((a,b)=>b[0]-a[0] || a[1]-b[1]).forEach(([, , s])=>feedList.appendChild(s));
    scheduleHighlight(hits.slice(0,50).map(([, , s])=>s),q);
  } else {
    restoreFeedOrder();
    applyFilter();
  }
}
function scheduleSearch(){
  if(searchTimer) clearTimeout(searchTimer);
  searchTimer=setTimeout(()=>{
    searchTimer=0;
    if(exView.classList.contains('active')){
      exerciseListSearch(searchBox.value);
    } else {
      runSearch(searchBox.value);
    }
  },220);
}
const searchWrap=document.querySelector('.searchwrap');
const searchClear=document.getElementById('searchclear');
function updateSearchClear(){
  searchWrap.classList.toggle('has-value', !!searchBox.value);
}
searchBox.addEventListener('input',()=>{ updateSearchClear(); scheduleSearch(); });
searchClear.addEventListener('click',()=>{
  searchBox.value='';
  updateSearchClear();
  cancelDeferredWork();
  if(exView.classList.contains('active')){
    exerciseListSearch('');
  } else {
    runSearch('');
  }
  searchBox.focus();
});

/* ---- keyboard shortcuts ---- */
document.addEventListener('keydown',(e)=>{
  const typing = e.target.tagName==='INPUT' || e.target.tagName==='TEXTAREA' || e.target.isContentEditable;
  const isFindCombo = (e.key==='f' || e.key==='F') && (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey;
  if((e.key==='/' && !typing) || isFindCombo){
    e.preventDefault();
    searchBox.focus();
    searchBox.select();
  } else if(e.key==='Escape' && e.target===searchBox){
    searchBox.blur();
  } else if(e.key==='Escape' && document.activeElement!==searchBox && searchBox.value){
    searchBox.value='';
    updateSearchClear();
    cancelDeferredWork();
    if(exView.classList.contains('active')){
      exerciseListSearch('');
    } else {
      runSearch('');
    }
  }
});

/* ---- exercise history ---- */
const exView=document.getElementById('exercise');
const exDetail=document.getElementById('exdetail');
const exListWrap=document.getElementById('exall');
function openExercise(name){
  const rows=exData[name]||[];
  let h='<div class="exfilter"><a id="exback">← all exercises</a></div>';
  h+='<div class="exitem exhist"><h3>'+esc(name)+'</h3>';
  rows.forEach(r=>{
    h+='<div class="exrow"><a class="exhdate" href="'+esc(r.href)+'" title="Open in obsidian nvim">'+esc(r.label)+'</a>'
      +'<span class="exhnums">'+esc(r.reps)+' &nbsp;·&nbsp; <b>'+esc(r.weight)+'</b></span>';
    if(r.notes&&r.notes.length){
      h+='<div class="exhnotes">'+r.notes.map(n=>'<div class="exhnote">'+n+'</div>').join('')+'</div>';
    }
    h+='</div>';
  });
  h+='</div>';
  exDetail.innerHTML=h;
  exDetail.style.display='block';
  exListWrap.style.display='none';
  document.getElementById('exback').onclick=closeExercise;
}
function closeExercise(){
  exDetail.style.display='none';
  exListWrap.style.display='block';
}
function exerciseListSearch(q){
  // A new query while an exercise's history is open must return to the
  // (now-filtered) list immediately -- otherwise the detail view keeps
  // covering it and typing looks like it did nothing.
  if(exDetail.style.display==='block') closeExercise();
  filterExercises(q);
}
function esc(s){const d=document.createElement('div');d.textContent=s;return d.innerHTML;}

/* tap exercise name in feed -> open history */
document.querySelectorAll('.exname').forEach(b=>{
  b.addEventListener('click',()=>{ showView('exercise'); openExercise(b.dataset.ex); });
});
/* exercise list -> open history */
document.querySelectorAll('#exall a').forEach(a=>{
  a.addEventListener('click',()=>openExercise(a.dataset.ex));
});

/* ---- exercise list filter ---- */
const exLinks=[...document.querySelectorAll('#exall a')];
function filterExercises(q){
  q=normSearchWords(q.trim());
  exLinks.forEach(a=>{
    const name=normSearchWords(a.dataset.ex);
    const tokens=q.split(/\\s+/).filter(Boolean);
    a.classList.toggle('hidden', !!q && !tokens.every(t=>fuzzyToken(name,t)));
  });
}
"""


def main() -> int:
    if not TRAINING_DIR.is_dir():
        print(f"ERROR: {TRAINING_DIR} not found", file=sys.stderr)
        return 1

    sessions: list[Session] = []
    for path in sorted(TRAINING_DIR.rglob("*.md")):
        if SKIP_DIR_PARTS & set(path.parts):
            continue
        if path.name in SKIP_FILES:
            continue
        s = parse_session(path)
        if s is not None:
            sessions.append(s)

    if not sessions:
        print("ERROR: no valid sessions parsed", file=sys.stderr)
        return 1

    events = parse_events(TRAINING_DIR / EVENTS_FILE)

    sessions.sort(key=lambda s: s.date, reverse=True)  # newest first

    ex_index = build_exercise_index(sessions)

    # Merge sessions and events into one descending timeline. On the same date a
    # session is shown before its event(s); events keep their file order.
    timeline: list = []
    timeline.extend((s.date, 0, i, s) for i, s in enumerate(sessions))
    timeline.extend((e.date, 1, i, e) for i, e in enumerate(events))
    # newest date first; within a date sessions (kind 0) before events (kind 1);
    # ties keep insertion order (sessions already newest-first, events file order)
    timeline.sort(key=lambda t: (-t[0].toordinal(), t[1], t[2]))

    feed_html = "".join(
        render_session(item) if kind == 0 else render_event(item)
        for _, kind, _, item in timeline
    )
    program_filter_html = render_program_filter(sessions)

    # exercise list, most recently used first (ties broken alphabetically),
    # with appearance counts
    ex_links = "".join(
        f'<a data-ex="{html.escape(name, quote=True)}">{html.escape(name)} '
        f'<span class="cnt">{len(ex_index[name])}</span></a>'
        for name in sorted(
            sorted(ex_index, key=str.lower),
            key=lambda n: ex_index[n][0]["date"],
            reverse=True,
        )
    )

    generated = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    js = JS.replace("__EXDATA__", json.dumps(ex_index, ensure_ascii=False))

    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Training logbook</title>
<style>{CSS}</style></head>
<body><div class="wrap">
<header class="top">
  <h1>Training logbook</h1>
  <div class="meta">{len(sessions)} sessions · {len(ex_index)} exercises · generated {generated}</div>
</header>

<div class="controls">
  <div class="searchwrap">
    <svg class="searchicon" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
      <circle cx="9" cy="9" r="6.5" stroke="currentColor" stroke-width="1.6"/>
      <line x1="13.6" y1="13.6" x2="18" y2="18" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
    </svg>
    <input id="search" type="search" placeholder="Search" autocomplete="off">
    <button id="searchclear" class="searchclear" type="button" aria-label="Clear search" tabindex="-1">&times;</button>
    <kbd class="searchkbd">/</kbd>
  </div>
</div>

<div class="tabs" role="tablist">
  <button class="tab" role="tab" data-v="feed" aria-selected="true">Feed</button>
  <button class="tab" role="tab" data-v="exercise" aria-selected="false">By exercise</button>
</div>

<div class="view active" id="feed">
  <h2 class="eye">Sessions</h2>
  {program_filter_html}
  <div id="feedlist">{feed_html}</div>
</div>

<div class="view" id="exercise">
  <div id="exdetail" style="display:none"></div>
  <h2 class="eye">Exercise history</h2>
  <div id="exall" class="exall">{ex_links}</div>
</div>

<script>{js}</script>
</div></body></html>"""

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(page, encoding="utf-8")
    print(f"Wrote {OUTPUT} ({len(sessions)} sessions, {len(ex_index)} exercises)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
