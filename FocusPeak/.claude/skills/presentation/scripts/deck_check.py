"""Mechanical slide-design gate for the hackathon pitch deck.

Checks every content slide of a .pptx (all slides except the first and the
last) against the measurable rules of the five design principles of Phillips,
"How to avoid death by PowerPoint", TEDxStockholmSalon (see
references/phillips_five_principles.md). The rules that need judgement (one
message per slide, claim fidelity) stay with a human read-through.

Usage (python-pptx is the only dependency):
    uv run --with python-pptx python .claude/skills/presentation/scripts/deck_check.py DECK.pptx
    ... deck_check.py DECK.pptx --theme light --accent B23A40
    ... deck_check.py DECK.pptx --json

Exit code 1 if any slide has a FAIL. WARN items need a human look, not a fix.
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE, PP_PLACEHOLDER

TEMPLATE = None                                    # optional .pptx whose layout shapes count as chrome

ACCENT = "FF8C42"                                  # the ONE highlight colour (set by --accent)
THEME = "dark"                                     # "dark": light text on dark; "light": dark text on white
WHITE = {"FFFFFF", "F8F8F8"}
TITLE_TYPES = {PP_PLACEHOLDER.TITLE, PP_PLACEHOLDER.CENTER_TITLE}


def tone(hex6):
    """'accent', 'dark', 'grey', 'light', or 'hue' (a colour outside the palette)."""
    if hex6 == ACCENT:
        return "accent"
    r, g, b = (int(hex6[i:i + 2], 16) for i in (0, 2, 4))
    if max(r, g, b) - min(r, g, b) > 24:
        return "hue"
    v = (r + g + b) / 3
    return "dark" if v < 90 else "grey" if v < 200 else "light"


def text_ok(t):
    """True when a tone reads well on the slide background of THEME."""
    return t == "accent" or t == ("light" if THEME == "dark" else "dark")

MAX_OBJECTS = 6        # principle 5
MAX_BULLETS = 5        # section 4, bullets
MAX_WORDS_BULLET = 7   # section 4, bullets
MAX_WORDS_CELL = 6     # section 4, table cells
MAX_ROWS = 6           # table rows, header included
MAX_COLS = 4
MAX_BOX_LINES = 2      # a diagram box: a name plus one phrase
MIN_PT = 18            # smallest readable size in the room
FOCAL_PT = 28          # principle 3: the key item is the biggest
MAX_HEADING_CHARS = 22  # section 5, layout B heading box (TextBox 23)
MAX_HEADING_A_CHARS = 50  # section 5, layout A heading box ("Heading"), one line at 28 pt
MAX_LABEL_CHARS = 9     # "Diagnosis" fits; "Improvement" wraps (2026-10-06)
HEADING_A = "Heading"   # shape name of the layout A message line

SENTENCE = re.compile(r"\w[.!?]\s+\w|\w[.!?]$")
OF_N = re.compile(r"\b\d+\s*(of|/)\s*\d+\b", re.I)


def chrome_names(template):
    """Shape names that belong to the template content layouts (not content)."""
    if not template:
        return set()
    p = Presentation(template)
    slides = list(p.slides)
    names = set()
    for s in slides[1:-1]:
        names |= {sh.name for sh in s.shapes}
    return names


def walk(shapes):
    for sh in shapes:
        if sh.shape_type == MSO_SHAPE_TYPE.GROUP:
            yield from walk(sh.shapes)
        else:
            yield sh


def run_rgb(run):
    try:
        c = run.font.color
        if c and c.type is not None and c.rgb is not None:
            return str(c.rgb).upper()
    except (AttributeError, TypeError):
        pass
    return None


def para_units(tf):
    """One unit per non-empty paragraph: text, sizes, colours, bold."""
    out = []
    for p in tf.paragraphs:
        text = "".join(r.text for r in p.runs).strip()
        if not text:
            continue
        out.append({
            "text": text,
            "sizes": {r.font.size.pt for r in p.runs if r.font.size},
            "colours": {c for c in (run_rgb(r) for r in p.runs) if c},
            "bold": any(r.font.bold for r in p.runs),
        })
    return out


def check_slide(idx, slide, chrome):
    fails, warns = [], []
    label = heading = ""
    content = []
    for sh in slide.shapes:
        if sh.name == "TextBox 22" and sh.has_text_frame:
            label = sh.text_frame.text.strip()
        elif sh.name in ("TextBox 23", HEADING_A) and sh.has_text_frame:
            heading = sh.text_frame.text.strip()
            limit = MAX_HEADING_A_CHARS if sh.name == HEADING_A else MAX_HEADING_CHARS
        elif sh.is_placeholder and sh.placeholder_format.type in TITLE_TYPES and sh.has_text_frame:
            heading = sh.text_frame.text.strip()
            limit = MAX_HEADING_A_CHARS
        elif sh.name not in chrome:
            content.append(sh)

    objects = 0
    units = []           # every text unit in the content area
    # no grey, no low contrast: box outlines, connectors and chart series too
    for sh in walk(content):
        cols = []
        try:
            if sh.line.fill.type == 1:
                cols.append(("line", str(sh.line.color.rgb).upper()))
        except (AttributeError, TypeError, NotImplementedError):
            pass
        if getattr(sh, "has_chart", False) and sh.has_chart:
            for ser in sh.chart.plots[0].series:
                try:
                    cols.append(("chart series", str(ser.format.fill.fore_color.rgb).upper()))
                except (AttributeError, TypeError):
                    pass
        for what, c in cols:
            t = tone(c)
            if t == "grey" or (t != "hue" and not text_ok(t)):
                fails.append(f"{what} colour {c} has low contrast on the {THEME} background")
    bullets = 0
    for sh in walk(content):
        if sh.has_table:
            tbl = sh.table
            nrows, ncols = len(tbl.rows), len(tbl.columns)
            objects += nrows
            if nrows > MAX_ROWS:
                fails.append(f"table has {nrows} rows (max {MAX_ROWS}, header included)")
            if ncols > MAX_COLS:
                fails.append(f"table has {ncols} columns (max {MAX_COLS})")
            for r, row in enumerate(tbl.rows):
                for cell in row.cells:
                    if cell.fill.type is not None and cell.fill.type != 5:   # 5 = background
                        try:
                            col = str(cell.fill.fore_color.rgb).upper()
                        except (AttributeError, TypeError):
                            col = "theme"
                        if col not in WHITE:   # a white fill is the same as none
                            fails.append(f"table cell fill {col} (cells stay unfilled, use text contrast)")
                    for u in para_units(cell.text_frame):
                        u["kind"], u["header"] = "cell", r == 0
                        u["key"] = (sh.shape_id, r)        # a table row is one item
                        units.append(u)
        elif sh.shape_type in (MSO_SHAPE_TYPE.PICTURE, MSO_SHAPE_TYPE.CHART) or getattr(sh, "has_chart", False):
            objects += 1
        elif sh.has_text_frame and sh.text_frame.text.strip():
            us = para_units(sh.text_frame)
            if sh.shape_type == MSO_SHAPE_TYPE.TEXT_BOX:
                objects += len(us)
                bullets += len(us)
                for u in us:
                    u["kind"], u["header"] = "bullet", False
            else:   # a diagram box
                objects += 1
                if len(us) > MAX_BOX_LINES:
                    warns.append(f"diagram box '{us[0]['text'][:25]}' has {len(us)} lines (max {MAX_BOX_LINES})")
                for u in us:
                    u["kind"], u["header"] = "box", False
                    u["key"] = ("box", sh.shape_id)        # a diagram box is one item
            units += us
        # text-less arrows and connectors carry relations, not objects

    if objects > MAX_OBJECTS:
        fails.append(f"{objects} objects in the content area (max {MAX_OBJECTS})")
    if bullets > MAX_BULLETS:
        fails.append(f"{bullets} bullets (max {MAX_BULLETS})")

    for u in units:
        n = len(u["text"].split())
        if u["kind"] == "bullet" and n > MAX_WORDS_BULLET:
            fails.append(f"bullet has {n} words (max {MAX_WORDS_BULLET}): '{u['text'][:40]}'")
        if u["kind"] == "cell" and n > MAX_WORDS_CELL:
            warns.append(f"table cell has {n} words (max {MAX_WORDS_CELL}): '{u['text'][:40]}'")
        if n >= 6 and SENTENCE.search(u["text"]):
            if u["text"].rstrip().endswith("?"):
                warns.append(f"question sentence: shorten it to a phrase if you can: '{u['text'][:40]}'")
            else:
                fails.append(f"full sentence on the slide (move it to the notes): '{u['text'][:40]}'")
        for pt in u["sizes"]:
            if pt < MIN_PT:
                fails.append(f"text at {pt:g} pt (min {MIN_PT}): '{u['text'][:30]}'")
        for c in u["colours"]:
            t = tone(c)
            if t == "hue":
                fails.append(f"text colour {c} is outside the palette (one text colour plus one accent)")
            elif not text_ok(t):
                fails.append(f"text {c} has low contrast on the {THEME} background: '{u['text'][:30]}'")

    # principles 3 and 4: one focal item, made by size or by the red accent
    accent_units = [u for u in units if ACCENT in u["colours"]]
    accent_items = {u.get("key", id(u)) for u in accent_units}
    if len(accent_items) > 1:
        fails.append(f"accent colour on {len(accent_items)} items (max 1)")
    sized = [max(u["sizes"]) for u in units if u["sizes"] and not u["header"]]
    modal = Counter(sized).most_common(1)[0][0] if sized else None
    larger = [u for u in units if u["sizes"] and modal and max(u["sizes"]) > modal and not u["header"]]
    focal = {u.get("key", u["text"]) for u in accent_units + larger}
    if units and not focal and len(units) > 1:
        warns.append("no focal item: make the key item the biggest, or give it the accent colour")
    focal_pt = [max(u["sizes"]) for u in accent_units + larger if u["sizes"]]
    if focal_pt and max(focal_pt) < FOCAL_PT:
        warns.append(f"focal item is {max(focal_pt):g} pt (make it {FOCAL_PT} to 32 pt)")
    if len(focal) > 1 and not accent_units:
        warns.append(f"{len(focal)} items compete as the biggest text; pick one, or build the slide in steps")

    # chrome text
    if label and len(label.split()) > 1:
        warns.append(f"section label '{label}' is more than one word")
    if label and len(label) > MAX_LABEL_CHARS:
        fails.append(f"section label '{label}' is {len(label)} characters (max {MAX_LABEL_CHARS}, it wraps into the heading)")
    if heading and len(heading) > limit:
        warns.append(f"heading is {len(heading)} characters (max {limit}, one line)")

    notes = slide.notes_slide.notes_text_frame.text.strip() if slide.has_notes_slide else ""
    if not notes:
        warns.append("speaker notes are empty (the spoken words go in the notes)")
    elif not notes.lower().startswith("message:"):
        warns.append("notes do not start with 'Message: <one sentence>' (principle 1)")

    return {"slide": idx, "label": label, "heading": heading, "objects": objects,
            "fails": fails, "warns": warns}


def check_deck(path, template=TEMPLATE):
    chrome = chrome_names(template)
    p = Presentation(path)
    slides = list(p.slides)
    deck_fails = []
    for i, s in enumerate(slides, 1):
        for sh in walk(s.shapes):
            if sh.has_text_frame:
                t = sh.text_frame.text
                if "—" in t:
                    deck_fails.append(f"slide {i}: em-dash in '{t.strip()[:30]}'")
                if sh.name != "TextBox 9" and OF_N.search(t) and "Slide Number" in sh.name:
                    deck_fails.append(f"slide {i}: slide number shows a total")
    results = [check_slide(i, s, chrome) for i, s in enumerate(slides, 1) if 1 < i < len(slides)]
    return {"deck": str(path), "slides": len(slides), "deck_fails": deck_fails, "content": results}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("deck")
    ap.add_argument("--template", default=TEMPLATE, help="optional template .pptx; its layout shapes are ignored")
    ap.add_argument("--theme", choices=["dark", "light"], default="dark")
    ap.add_argument("--accent", default=None, help="accent colour RRGGBB (default FF8C42 dark, B23A40 light)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    global THEME, ACCENT
    THEME = a.theme
    ACCENT = (a.accent or ("FF8C42" if a.theme == "dark" else "B23A40")).upper().lstrip("#")
    r = check_deck(a.deck, a.template)
    if a.json:
        print(json.dumps(r, indent=1))
    else:
        print(f"{r['deck']}: {r['slides']} slides")
        for f in r["deck_fails"]:
            print(f"  FAIL  {f}")
        for s in r["content"]:
            head = f"{s['label']} / {s['heading']}".strip(" /")
            print(f"slide {s['slide']:>2} [{s['objects']} obj] {head}")
            for f in s["fails"]:
                print(f"  FAIL  {f}")
            for w in s["warns"]:
                print(f"  WARN  {w}")
    nfail = len(r["deck_fails"]) + sum(len(s["fails"]) for s in r["content"])
    nwarn = sum(len(s["warns"]) for s in r["content"])
    print(f"== {nfail} FAIL, {nwarn} WARN")
    sys.exit(1 if nfail else 0)


if __name__ == "__main__":
    main()
