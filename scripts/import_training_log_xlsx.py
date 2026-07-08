#!/usr/bin/env python3
"""Import Training_Log.xlsx history into markdown training sessions.

Dependency-free: reads the ``.xlsx`` as a zip of XML parts (no openpyxl).

Produces, under ``~/obsidian/training/``:

  - one ``YYYY-MM-DD-Day-N.md`` session file per workout, inside a folder named
    after the source Excel sheet;
  - a single ``events.md`` with curated timeline events.

See Training_Log_import_plan.md for the full specification.

Usage:
    python3 import_training_log_xlsx.py [--dry-run] [--overwrite] [Training_Log.xlsx]
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from xml.etree import ElementTree as ET

# --------------------------------------------------------------------------- #
# Config
# --------------------------------------------------------------------------- #
TRAINING_DIR = Path("~/obsidian/training").expanduser()
EPOCH = dt.date(1899, 12, 30)  # Excel 1900 date system base
COMMENT_AUTHOR_RE = re.compile(r"^(Федя Шапаренко|Шапаренко Федя)\s*:\s*", re.M)

M = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
RID = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"


def q(tag: str) -> str:
    return f"{{{M}}}{tag}"


# --------------------------------------------------------------------------- #
# Curated timeline events (from the import plan)
# --------------------------------------------------------------------------- #
CURATED_EVENTS = [
    ("2026-06-28", "neutral", "Перестал пить креатин (`creatine minus`)."),
    ("2026-06-14", "bad", "Ушиб левую кисть и правое плечо."),
    ("2026-04-09", "bad", "Ушиб палец."),
    ("2025-05-08", "neutral", "Креатин."),
    ("2025-02-26", "neutral", "Без креатина."),
    ("2024-08-01", "neutral", "С креатином."),
    ("2024-07-07", "neutral", "Без креатина."),
    ("2024-05-25", "neutral", "С креатином."),
]


# --------------------------------------------------------------------------- #
# Cell helpers
# --------------------------------------------------------------------------- #
def col_to_num(col: str) -> int:
    n = 0
    for ch in col:
        n = n * 26 + (ord(ch) - 64)
    return n


def num_to_col(n: int) -> str:
    s = ""
    while n > 0:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def split_ref(ref: str) -> tuple[str, int]:
    m = re.match(r"([A-Z]+)(\d+)", ref)
    return m.group(1), int(m.group(2))


def serial_to_date(serial: str) -> dt.date | None:
    try:
        n = int(round(float(serial)))
    except (TypeError, ValueError):
        return None
    if n < 1 or n > 80000:  # plausible 1900..2118 range
        return None
    return EPOCH + dt.timedelta(days=n)


# --------------------------------------------------------------------------- #
# Workbook reader
# --------------------------------------------------------------------------- #
@dataclass
class Cell:
    value: str  # resolved text value ("" if empty)
    is_date: bool  # cell uses a date number format
    comment: str | None = None  # cleaned comment text, if any
    fill: str | None = None  # solid fill colour as "RRGGBB" (no alpha), if any


class Sheet:
    """A sheet as a sparse dict of "A1" -> Cell, plus row/col lookups."""

    def __init__(self, cells: dict[str, Cell]):
        self.cells = cells
        self._rows: dict[int, dict[str, Cell]] = {}
        for ref, cell in cells.items():
            col, row = split_ref(ref)
            self._rows.setdefault(row, {})[col] = cell
        self.max_row = max(self._rows) if self._rows else 0

    def get(self, col: str, row: int) -> Cell | None:
        return self._rows.get(row, {}).get(col)

    def val(self, col: str, row: int) -> str:
        c = self.get(col, row)
        return c.value if c else ""

    def row(self, row: int) -> dict[str, Cell]:
        return self._rows.get(row, {})


class Workbook:
    def __init__(self, path: Path):
        self.z = zipfile.ZipFile(path)
        self.shared = self._shared_strings()
        self.date_styles = self._date_styles()
        self.style_fills = self._style_fills()
        self.sheet_targets, self.sheet_rels = self._sheet_index()

    # -- shared strings ----------------------------------------------------- #
    def _shared_strings(self) -> list[str]:
        try:
            root = ET.fromstring(self.z.read("xl/sharedStrings.xml"))
        except KeyError:
            return []
        out = []
        for si in root:
            out.append("".join(t.text or "" for t in si.iter(q("t"))))
        return out

    # -- date style detection ----------------------------------------------- #
    def _date_styles(self) -> set[int]:
        styles = ET.fromstring(self.z.read("xl/styles.xml"))
        builtin = set(range(14, 23)) | {45, 46, 47}
        custom_date_fmts: set[int] = set()
        numfmts = styles.find(q("numFmts"))
        if numfmts is not None:
            for nf in numfmts:
                code = nf.get("formatCode", "")
                # date if it has y/m/d tokens and is not purely a time format
                if re.search(r"[yYdD]", code) or "mmm" in code:
                    custom_date_fmts.add(int(nf.get("numFmtId")))
        cellxfs = styles.find(q("cellXfs"))
        date_idx: set[int] = set()
        for i, xf in enumerate(cellxfs):
            fid = int(xf.get("numFmtId", "0"))
            if fid in builtin or fid in custom_date_fmts:
                date_idx.add(i)
        return date_idx

    # -- fill colour per cell-style index ----------------------------------- #
    def _style_fills(self) -> dict[int, str]:
        """Map cellXfs index -> solid fill colour "RRGGBB".

        Only direct ``rgb`` fills are resolved (the mood colours are stored that
        way). Theme/indexed fills are ignored -> returns no colour for them.
        """
        styles = ET.fromstring(self.z.read("xl/styles.xml"))
        fills = styles.find(q("fills"))
        fill_rgb: dict[int, str] = {}
        for i, f in enumerate(fills):
            pf = f.find(q("patternFill"))
            if pf is None or pf.get("patternType") != "solid":
                continue
            fg = pf.find(q("fgColor"))
            if fg is None:
                continue
            rgb = fg.get("rgb")
            if rgb:
                fill_rgb[i] = rgb[-6:].upper()  # strip leading alpha (FF...)
        cellxfs = styles.find(q("cellXfs"))
        out: dict[int, str] = {}
        for i, xf in enumerate(cellxfs):
            fid = int(xf.get("fillId", "0"))
            if fid in fill_rgb:
                out[i] = fill_rgb[fid]
        return out

    # -- sheet name -> target xml + comments target ------------------------- #
    def _sheet_index(self):
        wb = ET.fromstring(self.z.read("xl/workbook.xml"))
        rels = ET.fromstring(self.z.read("xl/_rels/workbook.xml.rels"))
        rid_target = {r.get("Id"): r.get("Target") for r in rels}
        targets: dict[str, str] = {}
        for s in wb.find(q("sheets")):
            target = rid_target[s.get(RID)]
            if not target.startswith("xl/"):
                target = "xl/" + target
            targets[s.get("name")] = target
        return targets, None

    # -- comments for a given sheet ----------------------------------------- #
    def _comments(self, sheet_target: str) -> dict[str, str]:
        # sheet_target like "xl/worksheets/sheet5.xml"
        base = sheet_target.rsplit("/", 1)[1]  # sheet5.xml
        rels_path = f"xl/worksheets/_rels/{base}.rels"
        try:
            rels = ET.fromstring(self.z.read(rels_path))
        except KeyError:
            return {}
        comments_target = None
        for r in rels:
            tgt = r.get("Target") or ""
            if "comments" in tgt:
                comments_target = tgt.replace("../", "xl/")
                break
        if not comments_target:
            return {}
        root = ET.fromstring(self.z.read(comments_target))
        out: dict[str, str] = {}
        cl = root.find(q("commentList"))
        if cl is None:
            return {}
        for c in cl:
            ref = c.get("ref")
            text = "".join(t.text or "" for t in c.iter(q("t")))
            text = COMMENT_AUTHOR_RE.sub("", text).strip()
            if text:
                out[ref] = text
        return out

    # -- read a full sheet -------------------------------------------------- #
    def read_sheet(self, name: str) -> Sheet:
        target = self.sheet_targets[name]
        root = ET.fromstring(self.z.read(target))
        data = root.find(q("sheetData"))
        comments = self._comments(target)
        cells: dict[str, Cell] = {}
        for row in data:
            for c in row:
                ref = c.get("r")
                t = c.get("t")
                style = c.get("s")
                sidx = int(style) if style is not None else None
                is_date = sidx is not None and sidx in self.date_styles
                fill = self.style_fills.get(sidx) if sidx is not None else None
                value = ""
                v = c.find(q("v"))
                isel = c.find(q("is"))
                if t == "s":
                    if v is not None and v.text is not None:
                        value = self.shared[int(v.text)]
                elif t == "inlineStr" and isel is not None:
                    value = "".join(x.text or "" for x in isel.iter(q("t")))
                elif v is not None and v.text is not None:
                    value = v.text
                cells[ref] = Cell(
                    value=value, is_date=is_date, comment=comments.get(ref), fill=fill
                )
        # attach comments that landed on otherwise-empty cells
        for ref, text in comments.items():
            if ref not in cells:
                cells[ref] = Cell(value="", is_date=False, comment=text)
        return Sheet(cells)


# --------------------------------------------------------------------------- #
# Value normalisation
# --------------------------------------------------------------------------- #
# Mood is encoded by the fill colour of a session's notes cell. Green means a
# normal/good session and is intentionally NOT tagged (green is the base fill
# and would tag almost every workout). Only orange and red carry a mood tag.
MOOD_FILLS = {
    "E8A541": "mid",   # orange
    "FCBB58": "mid",   # lighter orange
    "FF0000": "bad",   # red
}


def fill_to_mood(fill: str | None) -> str | None:
    """Return "mid" / "bad" for a mood fill colour, else None (green/other)."""
    if not fill:
        return None
    return MOOD_FILLS.get(fill.upper())


def clean_name(name: str) -> str:
    name = name.replace("\n", " ").replace("\r", " ")
    name = re.sub(r"\s+", " ", name).strip()
    return name


def decimal_fix(text: str) -> str:
    """Replace a Russian decimal comma with a dot: 64,5 -> 64.5, 84,05+6,25 -> 84.05+6.25."""
    return re.sub(r"(?<=\d),(?=\d)", ".", text)


RESTORED_WEIGHTS: list[tuple[str, str]] = []  # (original, restored) for the report


def fix_weight(raw: str, is_date: bool) -> str:
    """Normalise a weight display value.

    - Excel-autodate corruption (a date-serial sitting in a weight cell) is
      restored as ``day.month`` (e.g. 2026-05-12 -> 12.5).  This happens both
      when the cell carries a date number format *and* when it is a bare serial
      far above any plausible weight (Excel sometimes drops the date style).
    - decimal commas become dots.
    """
    raw = (raw or "").strip()
    if not raw:
        return ""
    looks_serial = bool(re.fullmatch(r"\d{5}", raw)) and int(raw) >= 40000
    if is_date or looks_serial:
        d = serial_to_date(raw)
        if d is not None:
            restored = f"{d.day}.{d.month}"
            RESTORED_WEIGHTS.append((raw, restored))
            return restored
    return decimal_fix(raw)


def reps_modern(raw: str) -> str:
    """Modern reps cell -> spec reps.

    ``3x10-10-11`` -> ``3x10,10,11`` (so the generator strips the Nx prefix);
    ``2X8`` -> ``2x8``; ``3x12`` stays ``3x12``.
    """
    raw = (raw or "").strip()
    raw = raw.replace("X", "x").replace("х", "x").replace("Х", "x")
    raw = re.sub(r"\s+", "", raw)
    # turn "NxA-B-C" set lists into comma form
    m = re.match(r"^(\d+)x(.+)$", raw)
    if m and ("-" in m.group(2) or "," in m.group(2)):
        body = m.group(2).replace("-", ",")
        return f"{m.group(1)}x{body}"
    # bare set list without an Nx prefix: "20-14-8" -> "3x20,14,8"
    if re.fullmatch(r"\d+([-,]\d+)+", raw):
        parts = re.split(r"[-,]", raw)
        return f"{len(parts)}x{','.join(parts)}"
    return raw


def collapse_sets(reps: list[str], weights: list[str]) -> tuple[str, str]:
    """Collapse per-set reps/weights into spec display values.

    reps  10,10,10  -> 3x10 ;  12,12,10 -> 3x12,12,10
    weight 45,45,45 -> 45   ;  45,50,50 -> 45-50-50
    """
    reps = [r.strip() for r in reps if r.strip() != ""]
    weights = [w.strip() for w in weights if w.strip() != ""]
    n = len(reps)
    if n == 0:
        rep_s = ""
    elif len(set(reps)) == 1:
        rep_s = f"{n}x{reps[0]}"
    else:
        rep_s = f"{n}x{','.join(reps)}"
    if not weights:
        weight_s = ""
    elif len(set(weights)) == 1:
        weight_s = weights[0]
    else:
        weight_s = "-".join(weights)
    return rep_s, weight_s


def apply_unit(weight: str, unit: str) -> str:
    unit = (unit or "").strip().lower()
    weight = weight.strip()
    if not weight:
        return weight
    if unit and unit != "kg":
        return f"{weight} {unit}"
    return weight


# --------------------------------------------------------------------------- #
# Parsed data model
# --------------------------------------------------------------------------- #
@dataclass
class Exercise:
    name: str
    reps: str
    weight: str
    notes: list[str] = field(default_factory=list)


@dataclass
class WorkoutSession:
    date: dt.date
    sheet: str
    notes: list[str] = field(default_factory=list)
    exercises: list[Exercise] = field(default_factory=list)
    extra_comments: list[str] = field(default_factory=list)  # unmatched comments
    mood: str | None = None  # "bad" | "mid" | "great" | None


# --------------------------------------------------------------------------- #
# Block / column helpers
# --------------------------------------------------------------------------- #
def find_date_rows(sheet: Sheet, date_col: str) -> list[int]:
    """Rows whose *date_col* holds an Excel date -> session start rows."""
    rows = []
    for r in range(1, sheet.max_row + 1):
        c = sheet.get(date_col, r)
        if c is None or not c.value:
            continue
        if c.is_date and serial_to_date(c.value) is not None:
            rows.append(r)
    return rows


# Bare creatine markers are represented by curated timeline events, so they are
# dropped from session notes to avoid duplication.
CREATINE_NOTE_RE = re.compile(
    r"^-?\s*(creatine\s*(minus|plus)?|без\s+креатина|с\s+креатином|креатин)\.?$",
    re.I,
)


def normalise_notes(raw: str) -> list[str]:
    """Turn an Excel mood/notes cell into markdown bullet blocks."""
    raw = (raw or "").strip()
    if not raw:
        return []
    lines = [l.rstrip() for l in raw.split("\n")]
    blocks: list[str] = []
    for line in lines:
        s = line.strip()
        if not s:
            continue
        if CREATINE_NOTE_RE.match(s):
            continue
        if s.startswith("- "):
            blocks.append(s)
        elif re.match(r"^\d+[.)]\s+", s):
            blocks.append("- " + re.sub(r"^\d+[.)]\s+", "", s))
        else:
            blocks.append("- " + s)
    return blocks


# --------------------------------------------------------------------------- #
# Parser: modern collapsed sheets (Full Body 2026 / Full Body 2025 (2026))
# --------------------------------------------------------------------------- #
def parse_modern(sheet: Sheet, sheet_name: str, date_col: str, notes_col: str,
                 first_ex_col: str) -> list[WorkoutSession]:
    """Block layout:

        row R   : date(date_col) | day | notes(notes_col) | ex names (step 3)
        row R+1 : Reps / Weight headers
        row R+2 : reps values | weight values | unit (step 3)
    """
    sessions = []
    date_rows = find_date_rows(sheet, date_col)
    first_col_n = col_to_num(first_ex_col)
    for R in date_rows:
        date = serial_to_date(sheet.val(date_col, R))
        sess = WorkoutSession(date=date, sheet=sheet_name)
        notes_cell = sheet.get(notes_col, R)
        sess.mood = fill_to_mood(notes_cell.fill if notes_cell else None)
        sess.notes = normalise_notes(sheet.val(notes_col, R))
        # session-level comments on date/notes/day cells
        for col in (date_col, notes_col):
            cell = sheet.get(col, R)
            if cell and cell.comment:
                sess.notes.extend(normalise_notes(cell.comment))

        val_row = R + 2  # values two rows below the names
        step = 3
        col_n = first_col_n
        while True:
            name_col = num_to_col(col_n)
            rep_col = num_to_col(col_n)
            weight_col = num_to_col(col_n + 1)
            unit_col = num_to_col(col_n + 2)
            name = clean_name(sheet.val(name_col, R))
            if not name:
                break
            reps = reps_modern(sheet.val(rep_col, val_row))
            wcell = sheet.get(weight_col, val_row)
            weight = fix_weight(wcell.value if wcell else "", wcell.is_date if wcell else False)
            unit = sheet.val(unit_col, val_row)
            ex = Exercise(name=name, reps=reps, weight=apply_unit(weight, unit))
            # exercise-level comments: name cell or its value cells
            for c in (sheet.get(name_col, R), sheet.get(rep_col, val_row),
                      sheet.get(weight_col, val_row)):
                if c and c.comment:
                    ex.notes.extend(normalise_notes(c.comment))
            sess.exercises.append(ex)
            col_n += step
        if sess.exercises:
            sessions.append(sess)
    return sessions


# --------------------------------------------------------------------------- #
# Parser: set-per-row sheets (Full Body 2024, Upper-Lower modern & old)
# --------------------------------------------------------------------------- #
def is_set_value(text: str) -> bool:
    """A real per-set reps value is a bare number (e.g. 8, 12, 10.5).

    Header/label cells from the *next* block ("Reps", "Exercise", an exercise
    name, ...) are not, so they terminate a block's set scan even when blocks
    are not separated by a fresh date serial.
    """
    text = text.strip()
    return text == "" or bool(re.fullmatch(r"\d+(?:[.,]\d+)?", text))


def collect_sets(sheet: "Sheet", reps_col: str, weight_col: str, start: int, end: int):
    """Collect (reps, weights) for consecutive set rows from *start* to *end*.

    Stops early at the first row whose reps cell is a non-numeric label, i.e.
    the header of a following block.
    """
    reps_list, weight_list = [], []
    for r in range(start, end):
        rep = sheet.val(reps_col, r).strip()
        wcell = sheet.get(weight_col, r)
        wval = wcell.value.strip() if wcell else ""
        if not is_set_value(rep):
            break
        if rep == "" and wval == "":
            continue
        reps_list.append(rep)
        weight_list.append(fix_weight(wval, wcell.is_date if wcell else False))
    return reps_list, weight_list


def parse_set_based(sheet: Sheet, sheet_name: str, date_col: str, notes_col: str | None,
                    groups: list[tuple[str, str, str, str]], name_row_offset: int,
                    value_start_offset: int) -> list[WorkoutSession]:
    """Generic set-per-row parser.

    *groups* is a list of (name_col, reps_col, weight_col, unit_col) per
    exercise slot. *name_row_offset* is where exercise names live relative to
    the date row; *value_start_offset* is where the first set's values live.
    Following set rows are read until the next date row (or a blank reps cell
    run).
    """
    sessions = []
    date_rows = find_date_rows(sheet, date_col)
    date_row_set = set(date_rows)
    for idx, R in enumerate(date_rows):
        date = serial_to_date(sheet.val(date_col, R))
        next_date = date_rows[idx + 1] if idx + 1 < len(date_rows) else sheet.max_row + 1
        sess = WorkoutSession(date=date, sheet=sheet_name)
        if notes_col:
            sess.notes = normalise_notes(sheet.val(notes_col, R))
        for col in {date_col, notes_col}:
            if not col:
                continue
            cell = sheet.get(col, R)
            if cell and cell.comment:
                sess.notes.extend(normalise_notes(cell.comment))

        name_row = R + name_row_offset
        value_start = R + value_start_offset
        for name_col, reps_col, weight_col, unit_col in groups:
            name = clean_name(sheet.val(name_col, name_row))
            if not name:
                continue
            reps_list, weight_list = collect_sets(
                sheet, reps_col, weight_col, value_start, next_date
            )
            reps_s, weight_s = collapse_sets(reps_list, weight_list)
            unit = sheet.val(unit_col, value_start)
            ex = Exercise(name=name, reps=reps_s, weight=apply_unit(weight_s, unit))
            c = sheet.get(name_col, name_row)
            if c and c.comment:
                ex.notes.extend(normalise_notes(c.comment))
            sess.exercises.append(ex)
        if sess.exercises:
            sessions.append(sess)
    return sessions


# --------------------------------------------------------------------------- #
# Sheet-specific group builders
# --------------------------------------------------------------------------- #
def groups_step(first_col: str, step: int, count: int = 14):
    """Build (name, reps, weight, unit) tuples stepping by *step* columns.

    For step==3 the name and reps share a column (modern set layout F=name/reps).
    For step==4 the layout is name / reps / weight / unit.
    """
    out = []
    n = col_to_num(first_col)
    for _ in range(count):
        if step == 3:
            name = num_to_col(n)
            reps = num_to_col(n)
            weight = num_to_col(n + 1)
            unit = num_to_col(n + 2)
        else:  # step == 4: name | reps | weight | unit
            name = num_to_col(n)
            reps = num_to_col(n + 1)
            weight = num_to_col(n + 2)
            unit = num_to_col(n + 3)
        out.append((name, reps, weight, unit))
        n += step
    return out


# --------------------------------------------------------------------------- #
# Upper-Lower: detect modern vs old per block
# --------------------------------------------------------------------------- #
def parse_upper_lower(sheet: Sheet, sheet_name: str) -> list[WorkoutSession]:
    """Upper-Lower mixes two set-per-row layouts.

    Old block (category + header row):
        R   : date(C) | day(D) | Upper/Lower(E) | category names F/J/N (step 4)
        R+1 : Exercise / Reps / Weight headers per group
        R+2 : exercise names + first set values
        R+3.. more set values

    Modern block:
        R   : date(C) | day(D) | notes(E) | exercise names F/I/L (step 3)
        R+1 : Reps / Weight headers
        R+2 : first set values | unit
        R+3.. more set values
    """
    sessions = []
    date_rows = find_date_rows(sheet, "C")
    for idx, R in enumerate(date_rows):
        date = serial_to_date(sheet.val("C", R))
        next_date = date_rows[idx + 1] if idx + 1 < len(date_rows) else sheet.max_row + 1
        # detect: old block has "Exercise" header in F at R+1
        is_old = sheet.val("F", R + 1).strip().lower() == "exercise"
        if is_old:
            groups = groups_step("F", 4)
            sess = _parse_ul_block(sheet, sheet_name, date, R, next_date, groups,
                                   notes_col=None, name_row_offset=2, value_start_offset=2)
        else:
            groups = groups_step("F", 3)
            sess = _parse_ul_block(sheet, sheet_name, date, R, next_date, groups,
                                   notes_col="E", name_row_offset=0, value_start_offset=2)
        if sess.exercises:
            sessions.append(sess)
    return sessions


def _parse_ul_block(sheet, sheet_name, date, R, next_date, groups, notes_col,
                    name_row_offset, value_start_offset) -> WorkoutSession:
    sess = WorkoutSession(date=date, sheet=sheet_name)
    if notes_col:
        sess.notes = normalise_notes(sheet.val(notes_col, R))
    # Mood is the fill colour of the notes cell (E for both UL layouts).
    e_cell = sheet.get("E", R)
    sess.mood = fill_to_mood(e_cell.fill if e_cell else None)
    for col in {"C", notes_col, "E"}:
        if not col:
            continue
        cell = sheet.get(col, R)
        if cell and cell.comment:
            sess.notes.extend(normalise_notes(cell.comment))
    name_row = R + name_row_offset
    value_start = R + value_start_offset
    for name_col, reps_col, weight_col, unit_col in groups:
        name = clean_name(sheet.val(name_col, name_row))
        if not name:
            continue
        reps_list, weight_list = collect_sets(
            sheet, reps_col, weight_col, value_start, next_date
        )
        reps_s, weight_s = collapse_sets(reps_list, weight_list)
        unit = sheet.val(unit_col, value_start)
        if not unit.strip():
            # modern UL keeps unit on a separate row right under the header
            unit = sheet.val(unit_col, R + 2)
        ex = Exercise(name=name, reps=reps_s, weight=apply_unit(weight_s, unit))
        c = sheet.get(name_col, name_row)
        if c and c.comment:
            ex.notes.extend(normalise_notes(c.comment))
        sess.exercises.append(ex)
    return sess


# --------------------------------------------------------------------------- #
# Markdown emission
# --------------------------------------------------------------------------- #
def session_to_markdown(sess: WorkoutSession, day_n: int) -> str:
    stem = f"{sess.date.isoformat()}-Day-{day_n}"
    lines = []
    if sess.mood:
        lines += ["---", f"mood: {sess.mood}", "---"]
    lines += [f"# {stem}", ""]
    # table
    lines.append("| #   | Exercise | Reps | Weight |")
    lines.append("| --- | -------- | ---- | ------ |")
    for i, ex in enumerate(sess.exercises, 1):
        lines.append(f"| {i} | {ex.name} | {ex.reps} | {ex.weight} |")
    lines.append("")
    # general notes
    note_block: list[str] = list(sess.notes)
    # exercise notes keyed by their numeric code
    ex_note_lines: list[str] = []
    for i, ex in enumerate(sess.exercises, 1):
        for n in ex.notes:
            body = re.sub(r"^-\s*", "", n).strip()
            ex_note_lines.append(f"- {i}: {body}")
    all_notes = note_block + ex_note_lines
    if all_notes:
        lines.extend(all_notes)
        lines.append("")
    if sess.extra_comments:
        lines.append("### Excel comments")
        lines.append("")
        lines.extend(sess.extra_comments)
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
SHEET_PARSERS = {
    "Full Body 2026": lambda wb, s: parse_modern(s, "Full Body 2026", "A", "C", "D"),
    "Full Body 2025 (2026)": lambda wb, s: parse_modern(
        s, "Full Body 2025 (2026)", "C", "E", "F"
    ),
    "Upper-Lower": lambda wb, s: parse_upper_lower(s, "Upper-Lower"),
    "Full Body 2024": lambda wb, s: parse_set_based(
        s, "Full Body 2024", "C", None,
        groups_step("E", 4), name_row_offset=0, value_start_offset=0
    ),
}

# Output folder per sheet (defaults to the sheet name). The workbook sheet is
# still "Full Body 2025 (2026)", but on disk the folder was shortened.
SHEET_FOLDERS = {
    "Full Body 2025 (2026)": "Full Body 2025",
}


def build_events_md() -> str:
    # Written as a markdown list so the user's linter does not reflow the lines.
    lines = ["# Events", ""]
    for date, tag, text in CURATED_EVENTS:
        lines.append(f"- {date}: #{tag} {text}")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("xlsx", nargs="?", default="Training_Log.xlsx")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--overwrite", action="store_true")
    args = ap.parse_args()

    wb = Workbook(Path(args.xlsx))

    report = {
        "created": 0,
        "skipped_existing": 0,
        "restored_weights": [],
        "unmatched_comments": 0,
    }
    total_sessions = 0

    for sheet_name, parser in SHEET_PARSERS.items():
        if sheet_name not in wb.sheet_targets:
            print(f"WARNING: sheet {sheet_name!r} not found", file=sys.stderr)
            continue
        sheet = wb.read_sheet(sheet_name)
        sessions = parser(wb, sheet)
        total_sessions += len(sessions)
        print(f"{sheet_name}: {len(sessions)} sessions")

        # assign Day-N per date (handles two workouts on the same day)
        by_date: dict[dt.date, int] = {}
        out_dir = TRAINING_DIR / SHEET_FOLDERS.get(sheet_name, sheet_name)
        # Dates that already have a hand-written file *before* this run; those
        # win and the whole date is skipped so we never duplicate them. Snapshot
        # up front so freshly written Day-1 files don't shadow their own Day-2.
        preexisting_dates: set[str] = set()
        if out_dir.is_dir():
            for p in out_dir.glob("*-Day-*.md"):
                preexisting_dates.add(p.name[:10])
        for sess in sorted(sessions, key=lambda s: s.date):
            by_date[sess.date] = by_date.get(sess.date, 0) + 1
            day_n = by_date[sess.date]
            md = session_to_markdown(sess, day_n)
            path = out_dir / f"{sess.date.isoformat()}-Day-{day_n}.md"
            if args.dry_run:
                continue
            if sess.date.isoformat() in preexisting_dates and not args.overwrite:
                report["skipped_existing"] += 1
                continue
            out_dir.mkdir(parents=True, exist_ok=True)
            path.write_text(md, encoding="utf-8")
            report["created"] += 1

    # events.md
    events_path = TRAINING_DIR / "events.md"
    if not args.dry_run:
        if events_path.exists() and not args.overwrite:
            print(f"events.md exists, not overwriting ({len(CURATED_EVENTS)} curated)")
        else:
            events_path.write_text(build_events_md(), encoding="utf-8")
    print(f"events: {len(CURATED_EVENTS)}")
    print(f"Copypaste: skipped")
    print(f"total: {total_sessions} sessions, {len(CURATED_EVENTS)} events")

    if RESTORED_WEIGHTS:
        uniq = sorted(set(RESTORED_WEIGHTS))
        print(f"restored date-like weights: {len(RESTORED_WEIGHTS)} cells")
        for orig, fixed in uniq:
            print(f"  {orig} -> {fixed}")
    if not args.dry_run:
        print(
            f"created={report['created']} "
            f"skipped_existing={report['skipped_existing']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
