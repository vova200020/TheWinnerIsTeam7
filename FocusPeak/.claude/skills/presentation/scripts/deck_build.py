"""Deck builder for the hackathon pitch (python-pptx only).

Usage (python-pptx is the only dependency):
    # 16:9 dark deck: cover + N content slides + closing slide
    uv run --with python-pptx python .claude/skills/presentation/scripts/deck_build.py new pitch/pitch.pptx --slides 5
    # the same, cloned from a template deck (cover, layout A, layout B, closing)
    ... deck_build.py new pitch/pitch.pptx --template TEMPLATE.pptx --layout B --slides 5
    # PDF and one JPEG per slide, next to the deck (needs LibreOffice; JPEGs need pdftoppm)
    ... deck_build.py render pitch/pitch.pptx

As a library (fill the content after `new`):
    from deck_build import clone_slide, delete_slide, move_slide, renumber
"""
import argparse
import copy
import shutil
import subprocess
import sys
from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Inches, Pt

TEMPLATE = None                       # optional template deck: cover, layout A, layout B, closing
LAYOUT_SLIDE = {"A": 1, "B": 2}      # 0-based index of the content slide in the template
BG = RGBColor(0x0F, 0x14, 0x19)      # dark background (Phillips: dark gives the speaker the most contrast)
FG = RGBColor(0xE6, 0xE9, 0xEF)      # light text
SOFFICE = [r"C:\Program Files\LibreOffice\program\soffice.exe", "soffice", "libreoffice"]
R_ATTRS = ("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed",
           "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id",
           "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}link")


def clone_slide(prs, src):
    """Append a full copy of `src` (shapes, pictures, background). Returns the new slide."""
    new = prs.slides.add_slide(src.slide_layout)
    for shp in list(new.shapes):
        shp._element.getparent().remove(shp._element)
    rid_map = {}
    for rel in src.part.rels.values():
        if rel.reltype.endswith(("/notesSlide", "/slideLayout")):
            continue
        if rel.is_external:
            rid_map[rel.rId] = new.part.relate_to(rel.target_ref, rel.reltype, is_external=True)
        else:
            rid_map[rel.rId] = new.part.relate_to(rel.target_part, rel.reltype)
    src_csld, new_csld = src._element.cSld, new._element.cSld
    if src_csld.bg is not None:
        new_csld.insert(0, copy.deepcopy(src_csld.bg))
    tree = new.shapes._spTree
    for el in src.shapes._spTree.iterchildren():
        if el.tag.endswith(("}nvGrpSpPr", "}grpSpPr")):
            continue
        dup = copy.deepcopy(el)
        for node in dup.iter():
            for attr in R_ATTRS:
                if node.get(attr) in rid_map:
                    node.set(attr, rid_map[node.get(attr)])
        tree.append(dup)
    return new


def delete_slide(prs, index):
    lst = prs.slides._sldIdLst
    sld = lst[index]
    prs.part.drop_rel(sld.rId)
    lst.remove(sld)


def move_slide(prs, old, new):
    lst = prs.slides._sldIdLst
    sld = lst[old]
    lst.remove(sld)
    lst.insert(new, sld)


def renumber(prs):
    """Give every slide and notes part a unique name in deck order. Call before prs.save().

    python-pptx names a new slide by counting slides, so after delete_slide a new slide can get
    the name of a slide that is still in the deck. The saved file then holds two parts with one
    name, and PowerPoint and LibreOffice reject it (found 2026-10-06).
    """
    from pptx.opc.packuri import PackURI
    slides = list(prs.slides)
    for i, s in enumerate(slides, 1):                 # first move all names out of the way
        s.part.partname = PackURI(f"/ppt/slides/_tmp_slide{i}.xml")
        if s.has_notes_slide:
            s.notes_slide.part.partname = PackURI(f"/ppt/notesSlides/_tmp_notesSlide{i}.xml")
    for i, s in enumerate(slides, 1):
        s.part.partname = PackURI(f"/ppt/slides/slide{i}.xml")
        if s.has_notes_slide:
            s.notes_slide.part.partname = PackURI(f"/ppt/notesSlides/notesSlide{i}.xml")


def _dark(slide):
    fill = slide.background.fill
    fill.solid()
    fill.fore_color.rgb = BG


def _set_text(shape, text, pt, prs):
    shape.left, shape.width = Inches(0.6), prs.slide_width - Inches(1.2)
    tf = shape.text_frame
    tf.text = text
    for p in tf.paragraphs:
        for r in p.runs:
            r.font.size = Pt(pt)
            r.font.color.rgb = FG


def blank_deck(out, n=5):
    """16:9 dark deck without a template: cover, n title-only content slides, closing slide."""
    prs = Presentation()
    prs.slide_width, prs.slide_height = Inches(13.333), Inches(7.5)
    cover_layout, content_layout = prs.slide_layouts[0], prs.slide_layouts[5]   # Title, Title Only
    s = prs.slides.add_slide(cover_layout)
    _dark(s)
    _set_text(s.shapes.title, "Team name: the idea in one line", 40, prs)
    _set_text(s.placeholders[1], "Tech Thursday x Garmin hackathon", 24, prs)
    for i in range(n):
        s = prs.slides.add_slide(content_layout)
        _dark(s)
        _set_text(s.shapes.title, f"Message {i + 1}", 32, prs)
        s.notes_slide.notes_text_frame.text = "Message: "
    s = prs.slides.add_slide(content_layout)
    _dark(s)
    _set_text(s.shapes.title, "Try it on the watch", 40, prs)
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    prs.save(out)
    check = Presentation(out)                # reopen: confirms the file is intact
    print(f"{out}: {len(check.slides)} slides (cover, {n} content, closing)")
    return out


def new_deck(out, layout="A", n=5, template=TEMPLATE):
    """Cover, n content slides of the selected layout, Q and A. Template stays untouched."""
    if not template:
        return blank_deck(out, n)
    prs = Presentation(template)
    k = len(prs.slides)                      # cover, layout A, layout B, Q and A
    src = prs.slides[LAYOUT_SLIDE[layout]]
    for _ in range(n):
        clone_slide(prs, src)
    move_slide(prs, k - 1, len(prs.slides) - 1)        # Q and A to the end
    for i in (2, 1):                                     # drop the two template content slides
        delete_slide(prs, i)
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    renumber(prs)
    prs.save(out)
    check = Presentation(out)                # reopen: confirms the file is intact
    print(f"{out}: {len(check.slides)} slides (cover, {n} x layout {layout}, Q and A)")
    return out


def render(deck, dpi=110):
    """PDF next to the deck, then one JPEG per slide in <deck>_render/."""
    deck = Path(deck).resolve()
    exe = next((e for e in SOFFICE if shutil.which(e) or Path(e).exists()), None)
    if not exe:
        sys.exit("LibreOffice not found: install it, or export the PDF from PowerPoint")
    subprocess.run([exe, "--headless", "--convert-to", "pdf", "--outdir", str(deck.parent), str(deck)],
                   check=True, capture_output=True)
    pdf = deck.with_suffix(".pdf")
    outdir = deck.parent / f"{deck.stem}_render"
    outdir.mkdir(exist_ok=True)
    if shutil.which("pdftoppm"):
        subprocess.run(["pdftoppm", "-jpeg", "-r", str(dpi), str(pdf), str(outdir / "slide")], check=True)
    print(f"{pdf}\n{outdir}")
    return pdf


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("new")
    a.add_argument("out")
    a.add_argument("--layout", choices=["A", "B"], default="A")
    a.add_argument("--slides", type=int, default=5)
    a.add_argument("--template", default=TEMPLATE, help="optional template deck; without it a dark 16:9 deck is built")
    r = sub.add_parser("render")
    r.add_argument("deck")
    args = ap.parse_args()
    if args.cmd == "new":
        new_deck(args.out, args.layout, args.slides, args.template)
    else:
        render(args.deck)


if __name__ == "__main__":
    main()
