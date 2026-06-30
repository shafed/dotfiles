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

ROOT = Path(os.environ.get("LOGBOOK_ROOT", "~/obsidian/periodic")).expanduser()
TRAINING_DIR = ROOT / "training"
OUTPUT = TRAINING_DIR / "logbook.html"

FILENAME_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})-Day-\d+$")
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

    @property
    def weekday(self) -> str:
        return WEEKDAYS[self.date.weekday()]

    @property
    def label(self) -> str:
        return f"{self.date.isoformat()} ({self.weekday})"


# --------------------------------------------------------------------------- #
# Parsing
# --------------------------------------------------------------------------- #
def parse_reps(raw: str) -> str:
    """Apply spec reps rules.

    - if there is a comma -> drop the "Nx" prefix ("3x8,6,6" -> "8,6,6")
    - otherwise keep verbatim ("3x12" -> "3x12")
    """
    raw = raw.strip()
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
        elif line.strip() == "" and not cur:
            continue
        else:
            if cur:
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

    # 2) name partial match (case-insensitive), both directions.
    #    Prefer the longest matching exercise name to avoid greedy short hits.
    candidates = []
    for ex in exercises:
        nl = ex.name.lower()
        if nl and (nl in key_l or key_l in nl):
            candidates.append(ex)
    if candidates:
        return max(candidates, key=lambda e: len(e.name))
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
    lines = text.split("\n")

    exercises = parse_table(lines)
    if not exercises:
        print(
            f"WARNING: skipping {path.name}: no valid exercise table", file=sys.stderr
        )
        return None

    session = Session(date=date, path=path, exercises=exercises)

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
    stack: list[int] = []  # indentation levels with open <ul>

    for line in raw:
        if not is_item(line):
            # continuation text -> append to current li
            html_out.append(" " + md_inline(line.strip()))
            continue
        ind = _indent(line)
        if not stack:
            html_out.append("<ul>")
            stack.append(ind)
        elif ind > stack[-1]:
            # open nested list inside the previous <li> (replace its closer)
            if html_out and html_out[-1] == "</li>":
                html_out.pop()
            html_out.append("<ul>")
            stack.append(ind)
        else:
            while len(stack) > 1 and ind < stack[-1]:
                html_out.append("</ul></li>")
                stack.pop()
        html_out.append("<li>" + md_inline(item_text(line)) + "</li>")

    while stack:
        html_out.append("</ul>")
        if len(stack) > 1:
            html_out.append("</li>")
        stack.pop()

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
    # obsidian session via ~/dotfiles/scripts/nvim-edit-handler.sh. Path is percent-encoded.
    edit_uri = "nvim-edit://" + quote(str(s.path.resolve()))
    return (
        f'<article class="day" data-date="{s.date.isoformat()}" '
        f'data-year="{s.date.year}" data-month="{s.date.month:02d}">'
        f"<h3>{html.escape(s.label)}"
        f'<a class="srclink" href="{html.escape(edit_uri, quote=True)}" '
        f'title="Open in obsidian nvim">{html.escape(s.path.name)}</a>'
        "</h3>"
        f'<div class="exlist">{ex_html}</div>'
        f"{gen_html}"
        f"{extras_html}"
        "</article>"
    )


def build_exercise_index(sessions: list[Session]) -> dict:
    """exercise name -> list of appearances (newest first)."""
    index: dict[str, list[dict]] = {}
    for s in sessions:  # sessions already newest-first
        for ex in s.exercises:
            index.setdefault(ex.name, []).append(
                {
                    "date": s.date.isoformat(),
                    "label": s.label,
                    "reps": ex.reps,
                    "weight": ex.weight,
                    "notes": [md_block(n) for n in ex.notes],
                }
            )
    return index


def render_year_filter(sessions: list[Session]) -> str:
    years: dict[int, set[int]] = {}
    for s in sessions:
        years.setdefault(s.date.year, set()).add(s.date.month)

    parts = [
        '<button class="yf yf-all" data-year="all" aria-selected="true">All</button>'
    ]
    for year in sorted(years, reverse=True):
        months = sorted(years[year], reverse=True)
        mbtns = "".join(
            f'<button class="mf" data-year="{year}" data-month="{m:02d}">'
            f"{dt.date(year, m, 1).strftime('%b')}</button>"
            for m in months
        )
        parts.append(
            f'<div class="yblock"><button class="yf" data-year="{year}">{year}</button>'
            f'<div class="months">{mbtns}</div></div>'
        )
    return '<div class="yearfilter">' + "".join(parts) + "</div>"


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
.searchkbd{position:absolute;right:12px;font:500 11px/1 'Iosevka',ui-monospace,monospace;
  color:var(--soft);border:1px solid var(--line);background:var(--grid-alt);
  border-radius:5px;padding:3px 6px;pointer-events:none}
.searchwrap:focus-within .searchkbd{display:none}

.tabs{display:flex;gap:2px;margin:12px 0 6px;border-bottom:1px solid var(--line)}
.tab{appearance:none;border:0;background:none;font:inherit;font-size:13px;
  padding:8px 14px;cursor:pointer;color:var(--soft);border-bottom:2px solid transparent;
  margin-bottom:-1px;letter-spacing:.03em}
.tab[aria-selected=true]{color:var(--ink);border-color:var(--accent);font-weight:600}
.view{display:none} .view.active{display:block}
h2.eye{font:600 11px/1 inherit;text-transform:uppercase;letter-spacing:.18em;
  color:var(--accent);margin:14px 0 14px}

/* year/month filter */
.yearfilter{display:flex;flex-wrap:wrap;align-items:flex-start;gap:6px;margin:6px 0 16px}
.yf,.mf,.yf-all{appearance:none;border:1px solid var(--line);background:var(--panel);
  font:inherit;font-size:12px;padding:5px 11px;border-radius:6px;cursor:pointer;color:var(--soft)}
.yf[aria-selected=true],.yf-all[aria-selected=true],.mf[aria-selected=true]{
  background:var(--accent);border-color:var(--accent);color:#fff;font-weight:600}
.yblock{display:flex;flex-direction:column;gap:4px}
.months{display:flex;flex-wrap:wrap;gap:4px}
.mf{font-size:11px;padding:3px 8px}

/* session card */
.day{background:var(--panel);border:1px solid var(--line);border-radius:8px;
  padding:14px 16px;margin-bottom:14px}
.day.hidden{display:none}
.day h3{font:600 16px/1.2 'Georgia',serif;margin:0 0 12px;display:flex;
  align-items:baseline;gap:12px;flex-wrap:wrap}
.srclink{font:400 11px/1 'Iosevka',ui-monospace,monospace;color:var(--soft);
  text-decoration:none;word-break:break-all}
.srclink:hover{color:var(--accent);text-decoration:underline}

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
.exhdate{display:inline-block;width:130px;color:var(--soft);font-size:12px}
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
.exall .cnt{color:var(--soft);font-size:11px}

mark{background:var(--mark);color:inherit;border-radius:2px;padding:0 1px}
.empty{color:var(--soft);text-align:center;padding:40px 0}
"""

JS = """
const sessions=[...document.querySelectorAll('#feed .day')];
const exData=__EXDATA__;

/* tab switching */
const tabs=[...document.querySelectorAll('.tab')];
function showView(id){
  tabs.forEach(t=>t.setAttribute('aria-selected',t.dataset.v===id));
  document.querySelectorAll('.view').forEach(v=>v.classList.toggle('active',v.id===id));
}
tabs.forEach(t=>t.addEventListener('click',()=>showView(t.dataset.v)));

/* ---- year / month filter (feed) ---- */
let curYear='all', curMonth=null;
const yfBtns=[...document.querySelectorAll('.yf,.yf-all,.mf')];
function applyFilter(){
  sessions.forEach(s=>{
    let show=true;
    if(curYear!=='all'){
      show = s.dataset.year===String(curYear);
      if(show && curMonth) show = s.dataset.month===curMonth;
    }
    s.classList.toggle('hidden',!show);
  });
}
function setFilterSelected(){
  yfBtns.forEach(b=>{
    let sel=false;
    if(b.classList.contains('yf-all')) sel = curYear==='all';
    else if(b.classList.contains('mf')) sel = (b.dataset.year===String(curYear) && b.dataset.month===curMonth);
    else sel = (b.dataset.year===String(curYear) && !curMonth);
    b.setAttribute('aria-selected',sel);
  });
}
yfBtns.forEach(b=>b.addEventListener('click',()=>{
  if(searchBox.value){ searchBox.value=''; runSearch(''); }
  if(b.classList.contains('yf-all')){ curYear='all'; curMonth=null; }
  else if(b.classList.contains('mf')){ curYear=+b.dataset.year; curMonth=b.dataset.month; }
  else { curYear=+b.dataset.year; curMonth=null; }
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
function highlight(root,q){
  if(!q) return;
  const re=new RegExp(q.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&'),'gi');
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
function runSearch(q){
  q=q.trim();
  sessions.forEach(clearMarks);
  if(q){
    // search overrides the year/month filter
    curYear='all'; curMonth=null; setFilterSelected();
    showView('feed');
    const ql=q.toLowerCase();
    sessions.forEach(s=>{
      const hit=s.textContent.toLowerCase().includes(ql);
      s.classList.toggle('hidden',!hit);
      if(hit) highlight(s,q);
    });
  } else {
    applyFilter();
  }
}
searchBox.addEventListener('input',()=>runSearch(searchBox.value));

/* ---- keyboard shortcuts ---- */
document.addEventListener('keydown',(e)=>{
  const typing = e.target.tagName==='INPUT' || e.target.tagName==='TEXTAREA' || e.target.isContentEditable;
  const isFindCombo = (e.key==='f' || e.key==='F') && (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey;
  if((e.key==='/' && !typing) || isFindCombo){
    e.preventDefault();
    searchBox.focus();
    searchBox.select();
  } else if(e.key==='Escape' && e.target===searchBox){
    if(searchBox.value){ searchBox.value=''; runSearch(''); }
    searchBox.blur();
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
    h+='<div class="exrow"><span class="exhdate">'+esc(r.label)+'</span>'
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
function esc(s){const d=document.createElement('div');d.textContent=s;return d.innerHTML;}

/* tap exercise name in feed -> open history */
document.querySelectorAll('.exname').forEach(b=>{
  b.addEventListener('click',()=>{ showView('exercise'); openExercise(b.dataset.ex); });
});
/* exercise list -> open history */
document.querySelectorAll('#exall a').forEach(a=>{
  a.addEventListener('click',()=>openExercise(a.dataset.ex));
});
"""


def main() -> int:
    if not TRAINING_DIR.is_dir():
        print(f"ERROR: {TRAINING_DIR} not found", file=sys.stderr)
        return 1

    sessions: list[Session] = []
    for path in sorted(TRAINING_DIR.glob("*.md")):
        s = parse_session(path)
        if s is not None:
            sessions.append(s)

    if not sessions:
        print("ERROR: no valid sessions parsed", file=sys.stderr)
        return 1

    sessions.sort(key=lambda s: s.date, reverse=True)  # newest first

    ex_index = build_exercise_index(sessions)

    feed_html = "".join(render_session(s) for s in sessions)
    year_filter_html = render_year_filter(sessions)

    # exercise list (alphabetical), with appearance counts
    ex_links = "".join(
        f'<a data-ex="{html.escape(name, quote=True)}">{html.escape(name)} '
        f'<span class="cnt">{len(ex_index[name])}</span></a>'
        for name in sorted(ex_index, key=str.lower)
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
    <kbd class="searchkbd">/</kbd>
  </div>
</div>

<div class="tabs" role="tablist">
  <button class="tab" role="tab" data-v="feed" aria-selected="true">Feed</button>
  <button class="tab" role="tab" data-v="exercise" aria-selected="false">By exercise</button>
</div>

<div class="view active" id="feed">
  <h2 class="eye">Sessions</h2>
  {year_filter_html}
  <div id="feedlist">{feed_html}</div>
</div>

<div class="view" id="exercise">
  <h2 class="eye">Exercise history</h2>
  <div id="exdetail" style="display:none"></div>
  <div id="exall" class="exall">{ex_links}</div>
</div>

<script>{js}</script>
</div></body></html>"""

    OUTPUT.write_text(page, encoding="utf-8")
    print(f"Wrote {OUTPUT} ({len(sessions)} sessions, {len(ex_index)} exercises)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
