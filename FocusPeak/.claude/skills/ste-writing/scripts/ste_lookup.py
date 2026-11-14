#!/usr/bin/env python3
"""ste_lookup.py - ask the ASD-STE100 dictionary whether a word is approved.

The index at ../data/ste_dictionary_index.json was built from
notes/temp_notes/ASD-STE100_ISSUE9.pdf, part 2 (word list, pages 2-1-A1 to the end)
with ./build_dictionary_index.py on 2026-08-17.

ACCURACY, MEASURED
------------------
The index holds 2240 entries. The standard states 875 approved words and 1274 words that are
not approved, which is 2149. The index is therefore about 4% over that total, because the
column parser sometimes splits one entry into two, or joins a stray line from column 2.
A lookup is a strong indication, not a citation. Before a word choice becomes load-bearing in
a supervisor-facing or manuscript text, open the PDF page that the result names and read it.

USAGE
-----
  python ste_lookup.py ensure perform frailty
  python ste_lookup.py --file notes.md          # every distinct word in a file
  python ste_lookup.py --starts radar           # every entry that starts with "radar"
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "data" / "ste_dictionary_index.json"


def load() -> dict[str, list[dict]]:
    rows = json.loads(DATA.read_text(encoding="utf-8"))
    idx: dict[str, list[dict]] = {}
    for r in rows:
        idx.setdefault(r["head"].lower(), []).append(r)
    return idx


def report(word: str, idx: dict[str, list[dict]]) -> str:
    hits = idx.get(word.lower(), [])
    if not hits:
        return (f"{word:20s} NOT IN THE WORD LIST. It is permitted only if it is a technical noun "
                f"(rule 1.5) or a technical verb (rule 1.12) of this subject field.")
    out = []
    for h in hits:
        state = "APPROVED    " if h["approved"] else "NOT APPROVED"
        col2 = re.sub(r"\s+", " ", h["col2"])[:120]
        out.append(f"{word:20s} {state} p{h['p']:<4d} {h['entry'][:34]:36s} | {col2}")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description="Look a word up in the ASD-STE100 dictionary index.")
    ap.add_argument("words", nargs="*", help="the words to look up")
    ap.add_argument("--file", help="look up every distinct word in this file")
    ap.add_argument("--starts", help="list every entry whose headword starts with this string")
    args = ap.parse_args()

    if not DATA.is_file():
        print(f"ste_lookup: the index is missing at {DATA}. Rebuild it with build_dictionary_index.py.",
              file=sys.stderr)
        return 2
    idx = load()

    if args.starts:
        s = args.starts.lower()
        for head in sorted(k for k in idx if k.startswith(s)):
            print(report(head, idx))
        return 0

    words = list(args.words)
    if args.file:
        text = Path(args.file).read_text(encoding="utf-8", errors="replace")
        words += sorted({w.lower() for w in re.findall(r"\b[A-Za-z][A-Za-z'-]{2,}\b", text)})

    if not words:
        ap.print_help()
        return 2

    not_approved = 0
    for w in words:
        line = report(w, idx)
        if "NOT APPROVED" in line:
            not_approved += 1
            print(line)
        elif not args.file:
            print(line)
    if args.file:
        print(f"\n{not_approved} distinct words in {args.file} are listed as not approved.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
