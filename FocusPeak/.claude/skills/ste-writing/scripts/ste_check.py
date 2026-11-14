#!/usr/bin/env python3
"""ste_check.py - mechanical gate for ASD-STE100 Simplified Technical English (Issue 9).

Source of every ERROR rule: notes/temp_notes/ASD-STE100_ISSUE9.pdf, part 1 (writing rules),
read first-hand 2026-08-17. Each finding names the rule it comes from.

WHAT THIS TOOL DOES AND DOES NOT DO
-----------------------------------
It checks the rules that a machine can check: sentence length, paragraph length, punctuation,
contractions, Latin abbreviations, gendered pronouns, British spelling, and the words in the
dictionary "list of recurring errors" (part 2, pages 2-0-17 and 2-0-18).

It does NOT check the rules that need judgment: technical-noun categories (rule 1.5), multi-word
noun length (rule 2.1), whether a sentence has one topic (rule 6.5), whether a note gives an
instruction (rule 5.5), or whether a word has its approved MEANING (rule 9.2). A clean report is
not proof that a text is in STE.

SEVERITY
--------
  ERROR - the rule is in the standard and the check is reliable.
  WARN  - a heuristic. Read the line and decide. A warning is not always a defect.

USAGE
-----
  python code/ste_check.py FILE.md                  # descriptive text, 25-word limit
  python code/ste_check.py FILE.md --mode procedure # procedural text, 20-word limit
  python code/ste_check.py FILE.md --canadian       # permit Canadian/British spelling
  python code/ste_check.py FILE.md --quiet          # show the summary only
  python code/ste_check.py FILE.md --max-report 40  # limit the number of findings shown
  python code/ste_check.py - < text                 # read from standard input

EXEMPTING A VERBATIM REGION
---------------------------
  <!-- ste-check: off -->     ... a quotation, a copied table, the author's own words ...
  <!-- ste-check: on -->

EXIT CODE
---------
  0 = no ERROR findings.  1 = one or more ERROR findings.  2 = the tool could not run.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# --------------------------------------------------------------------------------------
# Rule data taken verbatim from the standard
# --------------------------------------------------------------------------------------

# Part 2, pages 2-0-17 and 2-0-18: "List of recurring errors".
# Key = the word that is not approved. Value = the approved replacement.
RECURRING_ERRORS = {
    "acceptable": "PERMITTED (adj)",
    "alternate": "ALTERNATIVE (adj)",
    "avoid": "PREVENT (v)",
    "fit": "INSTALL (v)",
    "follow": "OBEY (v)",
    "however": "BUT (conj)",
    "insert": "PUT (v)",
    "main": "PRIMARY (adj)",
    "perform": "DO (v)",
    "portion": "PART (n)",
    "press": "PUSH (v)",
    "reach": "GET (v)",
    "rotate": "TURN (v)",
    "secure": "ATTACH (v) or SAFETY (v)",
    "shall": "MUST (v)",
    "should": "MUST (v)",
    "since": "BECAUSE (conj) when it gives a reason",
    "therefore": "THUS (adv) or AS A RESULT",
    "ensure": "MAKE SURE (v)",
    "ensures": "MAKE SURE (v)",
    "ensuring": "MAKE SURE (v)",
    "ensured": "MAKE SURE (v)",
}

# Same table, entries that must be matched as a phrase.
RECURRING_ERROR_PHRASES = {
    "have to": "use an action verb in the imperative form",
    "prior to": "BEFORE (conj)",
    "due to": "BECAUSE OF (prep) or BECAUSE (conj)",
}

# Part 2 word list, verified by direct lookup 2026-08-17. Words that this project's prose uses
# often and that the dictionary lists as NOT approved, with the approved alternative it gives.
PROJECT_NOT_APPROVED = {
    "utilize": "USE (v)",
    "utilizes": "USE (v)",
    "utilized": "USE (v)",
    "utilizing": "USE (v)",
    "utilise": "USE (v)",
    "significant": "IMPORTANT (adj)",
    "significantly": "reword; the dictionary gives IMPORTANT (adj) for the adjective",
    "via": "THROUGH (prep)",
    "conduct": "DO (v)",
    "conducted": "DO (v)",
    "obtain": "GET (v)",
    "obtained": "GET (v)",
    "various": "DIFFERENT (adj)",
    "critical": "VERY IMPORTANT",
    "implement": "DO (v)",
    "implemented": "DO (v)",
    "indicate": "SHOW (v) or IDENTIFY (v)",
    "indicates": "SHOW (v) or IDENTIFY (v)",
    "determine": "FIND (v), GIVE (v), SELECT (v), or CALCULATE (v)",
    "determined": "FIND (v), GIVE (v), SELECT (v), or CALCULATE (v)",
    "evaluate": "EXAMINE (v) or ANALYSIS (TN)",
    "assess": "CALCULATE (v) or ESTIMATE (n)",
    "enable": "LET (v)",
    "enables": "LET (v)",
    "allow": "LET (v)",
    "allows": "LET (v)",
    "achieve": "GET (v)",
    "establish": "MAKE SURE (v)",
    "analyze": "ANALYSIS (TN)",
    "comprehensive": "FULL (adj)",
    "provide": "GIVE (v) or SUPPLY (v)",
    "provides": "GIVE (v) or SUPPLY (v)",
    "provided": "GIVE (v) or SUPPLY (v)",
    "require": "NECESSARY (adj)",
    "requires": "NECESSARY (adj)",
    "required": "NECESSARY (adj)",
    "improve": "BETTER (adj)",
    "reduce": "DECREASE (v)",
    "reduces": "DECREASE (v)",
    "verify": "MAKE SURE (v)",
    "facilitate": "HELP (v) or MAKE ... EASIER",
    "ability": "CAN (v)",
    "capability": "FUNCTION (n) or CAN (v)",
    "may": "CAN (v)",
    "need": "NECESSARY (adj)",
    "people": "PERSON (n) or PERSONNEL (n)",
    "further": "MORE (adj/adv)",
    "over": "ABOVE (prep), ON (prep), or ALONG (prep)",
    "under": "BELOW (prep), IN (prep), or LESS THAN",
    "using": "USE (v) or WITH (prep)",
    "complete": "COMPLETED (adj) when it is an adjective",
    "both": "THE TWO",
    "any": "reword; the dictionary gives no single alternative",
}

# Rule 8.1: the semicolon is not permitted.
# Rule 4.2: contractions are not permitted.
CONTRACTIONS = re.compile(
    r"\b(?:don|doesn|didn|isn|aren|wasn|weren|can|couldn|won|wouldn|shouldn|hasn|haven|hadn)'t\b"
    r"|\b(?:it|that|there|here|what|who|he|she|let)'s\b"
    r"|\b(?:we|you|they|I)'(?:re|ve|ll|d|m)\b",
    re.IGNORECASE,
)

# GR-6: do not use Latin abbreviations.
LATIN_ABBREV = re.compile(r"(?<![A-Za-z])(e\.g\.|i\.e\.|etc\.|viz\.|cf\.|vs\.|N\.B\.)", re.IGNORECASE)

# GR-7: gender-specific pronouns are not permitted.
GENDERED = re.compile(r"\b(he|she|him|her|his|hers|himself|herself)\b", re.IGNORECASE)

# Rule 1.14: use American English spelling.
BRITISH_SPELLING = {
    "colour": "color", "colours": "colors", "coloured": "colored",
    "behaviour": "behavior", "behaviours": "behaviors", "behavioural": "behavioral",
    "centre": "center", "centres": "centers", "centred": "centered",
    "metre": "meter", "metres": "meters", "fibre": "fiber", "fibres": "fibers",
    "licence": "license", "defence": "defense", "offence": "offense",
    "analyse": "analyze", "analysed": "analyzed", "analysing": "analyzing",
    "organise": "organize", "organised": "organized", "organisation": "organization",
    "organisational": "organizational", "recognise": "recognize", "recognised": "recognized",
    "summarise": "summarize", "summarised": "summarized", "characterise": "characterize",
    "characterised": "characterized", "prioritise": "prioritize", "prioritised": "prioritized",
    "categorise": "categorize", "categorised": "categorized", "normalise": "normalize",
    "normalised": "normalized", "minimise": "minimize", "maximise": "maximize",
    "emphasise": "emphasize", "standardise": "standardize", "synchronise": "synchronize",
    "modelling": "modeling", "modelled": "modeled", "labelled": "labeled",
    "labelling": "labeling", "travelled": "traveled", "cancelled": "canceled",
    "programme": "program", "grey": "gray", "catalogue": "catalog", "dialogue": "dialog",
    "aluminium": "aluminum", "sulphur": "sulfur", "practise": "practice",
    "towards": "toward", "amongst": "among", "whilst": "while", "learnt": "learned",
}

# Rule 9.3: do not make phrasal verbs. Verified in part 1: "put out" and "give off".
# The rest are the phrasal verbs this project's prose uses. They are heuristics, so WARN.
PHRASAL_VERBS_ERROR = {"put out": "EXTINGUISH (v)", "give off": "RELEASE (v)"}
PHRASAL_VERBS_WARN = [
    "carry out", "carried out", "set up", "set out", "come up with", "look into",
    "figure out", "point out", "bring about", "break down", "rule out", "draw on",
    "take into account", "go through", "go down", "go up", "end up", "sort out",
]

# Rule 3.6: use the active voice. Only the -ed forms plus the frequent irregular past participles,
# to keep the false-positive rate low ("is one" is not the passive voice).
IRREGULAR_PP = ("shown|given|taken|made|done|seen|found|held|built|written|kept|left|sent|known|"
                "drawn|grown|thrown|driven|chosen|broken|spoken|frozen|proven|hidden|shot|cut|read")
PASSIVE = re.compile(
    rf"\b(?:is|are|was|were|be|been|being)\s+(?:\w+ly\s+)?(\w+ed|{IRREGULAR_PP})\b",
    re.IGNORECASE,
)

# Rule 3.2: the continuous tenses are not approved verb forms.
CONTINUOUS = re.compile(r"\b(?:is|are|was|were|be|been|being)\s+(\w+ing)\b", re.IGNORECASE)

# Project standard 8 (lifespace-thesis references/01_standards.md): no em-dashes.
EM_DASH = re.compile(r"[—–]")

# Abbreviations that must not end a sentence.
NO_SPLIT = {
    "e.g.", "i.e.", "etc.", "cf.", "vs.", "al.", "Dr.", "Prof.", "Mr.", "Ms.", "Mrs.", "St.",
    "Fig.", "Figs.", "Eq.", "Eqs.", "Ref.", "Refs.", "No.", "Vol.", "pp.", "approx.", "Inc.",
    "Jr.", "Sr.", "Ph.D.", "M.Sc.", "U.S.", "a.m.", "p.m.", "Sec.", "Ch.", "Tab.", "min.", "max.",
}

UNIT_WORDS = {
    "m", "cm", "mm", "km", "s", "ms", "us", "ns", "min", "h", "hr", "hrs", "kg", "g", "mg", "lb",
    "lbs", "n", "nm", "w", "kw", "mw", "hz", "khz", "mhz", "ghz", "db", "dbm", "v", "mv", "a",
    "ma", "psi", "kpa", "bar", "deg", "degrees", "rad", "j", "kj", "c", "f", "k", "in", "ft",
    "inches", "inch", "feet", "liters", "litres", "l", "ml", "%", "w/kg", "m/s", "cc/minute",
    "nm", "rpm", "fps", "sps", "gb", "mb", "kb", "tb", "bpm", "years", "year", "months", "month",
    "weeks", "week", "days", "day", "participants", "papers", "cells", "rises",
}


# --------------------------------------------------------------------------------------
# Finding
# --------------------------------------------------------------------------------------

@dataclass
class Finding:
    line: int
    severity: str          # "ERROR" or "WARN"
    rule: str              # for example "4.1" or "GR-6"
    message: str
    excerpt: str

    def render(self, path: str) -> str:
        return f"{path}:{self.line}  [{self.severity}] rule {self.rule}: {self.message}\n      {self.excerpt}"


# --------------------------------------------------------------------------------------
# Text preparation
# --------------------------------------------------------------------------------------

OFF_MARK = re.compile(r"<!--\s*ste-check:\s*off\s*-->", re.IGNORECASE)
ON_MARK = re.compile(r"<!--\s*ste-check:\s*on\s*-->", re.IGNORECASE)


def strip_markdown(lines: list[str]) -> list[tuple[int, str, str]]:
    """Keep the prose. Remove the parts that STE does not govern.

    Removed: fenced code, YAML front matter, tables, headings, HTML comments, link targets,
    inline code, image and link URLs, blockquote markers, and any region between
    `<!-- ste-check: off -->` and `<!-- ste-check: on -->`.

    The exemption markers exist because the standard exempts quoted text itself (rule 8.6) and
    tells you to keep the spelling of a quotation as it is (rule 1.14). A file that copies the
    standard, a paper, or the author's own words must be able to say so.

    The third element of each tuple is the kind of the line: "prose", "item" (the first line of a
    vertical-list item), or "item_cont" (a wrapped line of that item). Rule 6.6 counts the
    sentences in a PARAGRAPH. A vertical list is not a paragraph: rule 4.3 governs it.
    """
    out: list[tuple[int, str, str]] = []
    in_fence = False
    in_front_matter = False
    exempt = False
    for i, raw in enumerate(lines, start=1):
        line = raw.rstrip("\n")

        # A structural line is not prose, BUT it does end the paragraph that comes before it.
        # Emit an empty line in its place, or the paragraph check (rule 6.6) joins two paragraphs
        # that a heading, a table, or a code block separates.
        def structural():
            out.append((i, "", "prose"))
            return None

        if OFF_MARK.search(line):
            exempt = True
            structural()
            continue
        if ON_MARK.search(line):
            exempt = False
            structural()
            continue
        if exempt:
            structural()
            continue

        if i == 1 and line.strip() == "---":
            in_front_matter = True
            continue
        if in_front_matter:
            if line.strip() == "---":
                in_front_matter = False
            structural()
            continue

        if re.match(r"^\s*(```|~~~)", line):
            in_fence = not in_fence
            structural()
            continue
        if in_fence:
            structural()
            continue

        if re.match(r"^\s*#{1,6}\s", line):          # heading: rule 8.6 counts it as one word
            structural()
            continue
        if re.match(r"^\s*\|", line):                 # table row
            structural()
            continue
        if re.match(r"^\s*(-{3,}|\*{3,}|={3,})\s*$", line):
            structural()
            continue
        if re.match(r"^\s*\[[^\]]+\]:\s*\S+", line):  # link definition
            structural()
            continue

        line = re.sub(r"<!--.*?-->", " ", line)
        line = re.sub(r"`[^`]*`", " CODE ", line)
        line = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", line)   # keep link text, drop the URL
        line = re.sub(r"https?://\S+", " URL ", line)
        indented = bool(re.match(r"^\s{2,}\S", line))
        line = re.sub(r"^\s*>+\s?", "", line)
        stripped, n_sub = re.subn(r"^\s*([-*+]|\d+[.)]|\(?[A-Za-z]\)|\(\d+\))\s+", "", line)
        line = stripped
        line = re.sub(r"\*\*|__|\*|_", "", line)

        # A vertical-list item is one unit (rule 4.3), and a wrapped line still belongs to the
        # item above it. Both must stay out of the paragraph count of rule 6.6.
        if n_sub:
            kind = "item"
        elif indented and out and out[-1][2] in ("item", "item_cont") and line.strip():
            kind = "item_cont"
        else:
            kind = "prose"

        out.append((i, line, kind))
    return out


BREAK = "\x01"   # marks a colon that ends a source line: rule 8.4 treats it as a period


def join_paragraph(items: list[tuple[str, str]]) -> str:
    """Join the source lines of one paragraph into one string.

    A sentence often wraps across two source lines. If the lines are checked one at a time,
    one sentence is counted as two, its length is under-counted, and rule 6.6 fires wrongly.
    A colon that ends a line introduces a vertical list, so it gets a break marker (rule 8.4).
    """
    out: list[str] = []
    for t, kind in items:
        t = t.replace(BREAK, "").strip()
        if not t:
            continue
        if kind == "item" and out:
            out[-1] += BREAK          # the item above ends here
        if t.endswith(":"):
            t += BREAK                 # rule 8.4
        out.append(t)
    return " ".join(out)


def split_sentences(text: str) -> list[str]:
    """Split on . ! ? and on a line-final colon (rule 8.4). A mid-sentence colon does not split."""
    text = re.sub(r"[ \t]+", " ", text).strip()
    if not text:
        return []
    parts, buf = [], ""
    for tok in text.split(" "):
        hard = tok.endswith(BREAK)
        tok = tok.replace(BREAK, "")
        buf = f"{buf} {tok}".strip()
        if hard:
            parts.append(buf)
            buf = ""
            continue
        if tok in NO_SPLIT:
            continue
        # A bare numeral with a period is a list number, not the end of a sentence.
        # An identifier such as "D-010." or "v1.4." IS the end of a sentence.
        if re.search(r"[.!?]$", tok) and not re.fullmatch(r"\d+\.", tok):
            parts.append(buf)
            buf = ""
    if buf:
        parts.append(buf)
    return [p for p in parts if p.strip()]


def count_words(sentence: str) -> int:
    """Count words the way section 8 counts them.

    Rule 8.5 - text in parentheses counts as one word.
    Rule 8.6 - a number, a number with its unit, an abbreviation, an alphanumeric identifier,
               and quoted text each count as one word.
    Rule 8.7 - a hyphenated word counts as one word.
    """
    s = sentence
    s = re.sub(r"\([^)]*\)", " PARENS ", s)                      # rule 8.5
    s = re.sub(r"\"[^\"]*\"|“[^”]*”", " QUOTED ", s)  # rule 8.6
    s = re.sub(r"(?<![\w.])[-+]?\d[\d,.]*\s*[A-Za-z%/]+\b", " NUMUNIT ", s)  # number + unit
    s = re.sub(r"(?<![\w.])[-+]?\d[\d,.]*\b", " NUM ", s)
    s = re.sub(r"[.,!?;:]+$", "", s)
    return len([w for w in s.split() if re.search(r"[\w%]", w)])


# --------------------------------------------------------------------------------------
# Checks
# --------------------------------------------------------------------------------------

def check_line(lineno: int, line: str, limit: int, canadian: bool) -> list[Finding]:
    f: list[Finding] = []
    low = line.lower()

    def add(sev, rule, msg, span=None):
        excerpt = line.strip() if span is None else line[max(0, span[0] - 30):span[1] + 30].strip()
        f.append(Finding(lineno, sev, rule, msg, excerpt.replace(BREAK, "")[:170]))

    for m in re.finditer(r";", line):
        add("ERROR", "8.1", "the semicolon is not permitted; write two sentences", m.span())
    for m in CONTRACTIONS.finditer(line):
        add("ERROR", "4.2", f"contraction \"{m.group(0)}\"; write the words in full", m.span())
    for m in LATIN_ABBREV.finditer(line):
        add("ERROR", "GR-6", f"Latin abbreviation \"{m.group(0)}\"; use English words", m.span())
    for m in GENDERED.finditer(line):
        add("ERROR", "GR-7", f"gender-specific pronoun \"{m.group(0)}\"; use a neutral construction", m.span())
    for m in EM_DASH.finditer(line):
        add("ERROR", "project", "em-dash or en-dash in prose; use a colon, comma, or parentheses", m.span())

    for phrase, repl in PHRASAL_VERBS_ERROR.items():
        for m in re.finditer(rf"\b{re.escape(phrase)}\b", low):
            add("ERROR", "9.3", f"phrasal verb \"{phrase}\"; use {repl}", m.span())
    for phrase in PHRASAL_VERBS_WARN:
        for m in re.finditer(rf"\b{re.escape(phrase)}\b", low):
            add("WARN", "9.3", f"possible phrasal verb \"{phrase}\"; use one approved verb", m.span())

    for phrase, repl in RECURRING_ERROR_PHRASES.items():
        for m in re.finditer(rf"\b{re.escape(phrase)}\b", low):
            add("ERROR", "1.1", f"\"{phrase}\" is not approved; use {repl}", m.span())

    for m in re.finditer(r"\b[A-Za-z][A-Za-z'-]*\b", line):
        w = m.group(0).lower()
        if w in RECURRING_ERRORS:
            add("ERROR", "1.1", f"\"{w}\" is in the list of recurring errors; use {RECURRING_ERRORS[w]}", m.span())
        elif w in PROJECT_NOT_APPROVED:
            add("ERROR", "1.1", f"\"{w}\" is not approved; use {PROJECT_NOT_APPROVED[w]}", m.span())
        if not canadian and w in BRITISH_SPELLING:
            add("ERROR", "1.14", f"British spelling \"{w}\"; write \"{BRITISH_SPELLING[w]}\"", m.span())

    for m in CONTINUOUS.finditer(line):
        add("WARN", "3.2", f"continuous tense \"{m.group(0)}\"; the simple tenses are the approved forms", m.span())
    for m in PASSIVE.finditer(line):
        add("WARN", "3.6", f"possible passive voice \"{m.group(0)}\"; use the active voice", m.span())

    return f


def check_paragraphs(pairs: list[tuple[int, str, str]], limit: int) -> list[Finding]:
    """Paragraph-level checks: rule 6.6 (six sentences) and the sentence-length limit.

    Both must run on the whole paragraph, because a sentence can wrap across source lines.
    """
    findings: list[Finding] = []
    block: list[tuple[str, str]] = []
    start: int | None = None

    def flush():
        if not block or start is None:
            return
        prose = [(t, k) for t, k in block if k == "prose"]
        n_prose = len(split_sentences(join_paragraph(prose)))
        if n_prose > 6:
            findings.append(Finding(start, "ERROR", "6.6",
                                    f"paragraph has {n_prose} sentences; the limit is six",
                                    block[0][0].replace(BREAK, "").strip()[:150]))
        sents = split_sentences(join_paragraph(block))
        for sent in sents:
            n = count_words(sent)
            if n > limit:
                findings.append(Finding(start, "ERROR", "6.3" if limit == 25 else "5.1",
                                        f"sentence has {n} words; the limit is {limit}",
                                        sent.replace(BREAK, "")[:150] + ("..." if len(sent) > 150 else "")))

    for lineno, text, kind in pairs:
        if text.strip():
            if not block:
                start = lineno
            block.append((text, kind))
        else:
            flush()
            block, start = [], None
    flush()
    return findings


# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="Check a text against the ASD-STE100 rules that a machine can check.")
    ap.add_argument("path", help="the file to check, or - for standard input")
    ap.add_argument("--mode", choices=["descriptive", "procedure"], default="descriptive",
                    help="descriptive = 25 words (rule 6.3); procedure = 20 words (rule 5.1)")
    ap.add_argument("--canadian", action="store_true",
                    help="permit Canadian/British spelling (participant-facing and UCalgary-facing documents)")
    ap.add_argument("--quiet", action="store_true", help="print the summary only")
    ap.add_argument("--max-report", type=int, default=60, help="the maximum number of findings to print")
    ap.add_argument("--warn-only", action="store_true", help="always exit 0")
    args = ap.parse_args()

    if args.path == "-":
        lines, label = sys.stdin.read().splitlines(True), "<stdin>"
    else:
        p = Path(args.path)
        if not p.is_file():
            print(f"ste_check: cannot read {p}", file=sys.stderr)
            return 2
        lines, label = p.read_text(encoding="utf-8", errors="replace").splitlines(True), str(p)

    limit = 25 if args.mode == "descriptive" else 20
    pairs = strip_markdown(lines)

    findings: list[Finding] = []
    for lineno, text, _kind in pairs:
        if text.strip():
            findings.extend(check_line(lineno, text, limit, args.canadian))
    findings.extend(check_paragraphs(pairs, limit))
    findings.sort(key=lambda x: (x.line, x.severity != "ERROR"))

    errors = [x for x in findings if x.severity == "ERROR"]
    warns = [x for x in findings if x.severity == "WARN"]

    if not args.quiet:
        for x in findings[:args.max_report]:
            print(x.render(label))
        if len(findings) > args.max_report:
            print(f"... {len(findings) - args.max_report} more findings not shown "
                  f"(raise --max-report to see them)")

    by_rule: dict[str, int] = {}
    for x in errors:
        by_rule[x.rule] = by_rule.get(x.rule, 0) + 1
    top = ", ".join(f"{r}x{c}" for r, c in sorted(by_rule.items(), key=lambda kv: -kv[1])[:6])
    print(f"\nSTE gate: {len(errors)} ERROR, {len(warns)} WARN in {label} "
          f"(mode={args.mode}, limit={limit} words){' | ' + top if top else ''}")
    print("Judgment rules are NOT checked here: 1.5, 2.1, 5.5, 6.5, 9.2. A clean report is not proof of STE.")
    return 0 if (not errors or args.warn_only) else 1


if __name__ == "__main__":
    sys.exit(main())
