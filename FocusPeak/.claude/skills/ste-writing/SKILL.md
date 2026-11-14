---
name: ste-writing
description: "Use for the WORDING of every document or message generated in this hackathon repo (chat reply, START_HERE.md, MAP.md, findings or research file, report, plan, runbook, setup or wiring steps, checklist, commit message, code comment): ASD-STE100 Issue 9 rules, the ste_check.py gate and the dictionary lookup, plus the verdict skeleton. Layout, visuals and HTML belong to report-standard. Trigger also on ASD-STE100, STE, plain English, 'shorter sentences', 'too wordy'. NOT for the pitch script, slide text or text on the watch screen (presentation and hackathon-code-standard own those)."
---

# Writing and generating documents in this repo

One skill, two halves.

| Half | What it sets |
|---|---|
| **STRUCTURE** | What the document is made of: tables, skeleton, visuals, what stays out |
| **WORDING** | How each sentence reads: ASD-STE100 Simplified Technical English (STE), Issue 9 |

## Not in scope

The assistant never rewrites one of these into STE:

| Item | Owner |
|---|---|
| The pitch script, slide text, the demo voice-over | `presentation` (spoken, short, persuasive) |
| Text on the watch screen, glance and notification text | `hackathon-code-standard` section 7 |
| A verbatim quotation | Keep it as it is |
| A source identifier: URL, DOI, datasheet or app-note number | Keep it as it is |
| A file path, code, a command, a formula | Keep it as it is |
| A sentence that the user wrote | Keep it as it is |

## The contract

1. Pick the document type in step 1. Build its structure. Then write the words.
2. Run the gate before you give the file to the user.
3. STE changes wording, never a claim. A claim that moved during a wording pass is a defect.
4. Layout, visuals, dark mode and acronyms belong to `report-standard` (user-level skill). A quick
   fact-check of numbers and claims belongs to `ASG-audit`.

## Step 1. Structure: pick the document type

| Type | Skeleton | Sentence limit |
|---|---|---|
| Verdict, answer `.md`, state summary (`START_HERE.md`) | The six rules below, in full. Detail in `references/04_document_formats.md` | 25 words |
| Report, findings file, handout, plan, note, `MAP.md` | Title, one-line map, then tables. Same six rules, lighter | 25 words |
| Runbook, setup, wiring or flashing step, checklist, command sequence | Numbered steps, imperative form, one instruction per step | 20 words |
| Safety instruction (power, wiring, battery, radio) | Command or condition first, then the risk | 20 words |
| Chat reply | Answer first, tables for every enumerable set, no preamble | 25 words |
| PDF deliverable | `md-to-pdf` (user-level skill) renders it. This skill owns the Markdown | 25 words |
| HTML page | `report-standard` section 3 (template, page order by type) | 25 words |

## Step 2. The six structure rules

1. **Latest verified state ONLY.** No supersession trail, no "was X, corrected to Y", no change
   history. Open questions and fragile results DO stay, because they are current state. One
   exception: the dated change-sync ledger in `START_HERE.md`, which exists to sync sessions.
2. **Table-first.** Every enumerable set becomes a table: options, boards, tasks, statuses,
   sources. Prose only for the one-line map and short notes below a table. Checklists as GFM
   checkboxes. **A table that renders badly is a defect of this rule, not of the renderer**
   (`report-standard` section 5).
3. **Plain language.** Written for reading speed. Gloss each technical term once, so a teammate
   from another field follows it cold.
4. **Visuals: professional and dark-mode-safe.** Markdown read in a viewer: mermaid `flowchart`
   only, with NO style, fill or color directives, no mindmap, no timeline, plus a plain-ASCII
   twin. HTML: inline SVG by `report-standard`.
5. **Skeleton.** Section 0 is a one-line map of what is active, plus a status table with a "your
   open actions" column. Then one section per question, each led by its verdict table.
6. **Link what a teammate may need to check.** A web page: its URL. A vendor document: its name
   and the page (`BGT60TR13C datasheet, p. 12`). No other citation format.

## Step 3. Wording: the ten defects that occur most

| # | Rule | The defect | The correction |
|---|---|---|---|
| 1 | 6.3 / 5.1 | a sentence longer than the limit | divide it into two sentences |
| 2 | 8.1 | a semicolon | write two sentences |
| 3 | 1.1 | a word the dictionary does not approve | look it up, then use the approved alternative |
| 4 | 3.6 | the passive voice | give the sentence an agent, or use the imperative |
| 5 | 6.5 / 6.1 | more than one topic in one sentence | one topic per sentence, information given gradually |
| 6 | 6.6 | a paragraph longer than six sentences | divide it, and start each part with a topic sentence |
| 7 | 2.1 | a multi-word noun of more than three words | shorten it, or divide it with "of", "on", "in", "for" |
| 8 | GR-6 | a Latin abbreviation | write "for example", "that is", "and so on" |
| 9 | GR-3 / GR-4 | a pronoun that can point at two nouns | write the noun again |
| 10 | 9.4 | two different words for one item | select one word and keep it in the whole text |

Also: no contraction (4.2), no gendered pronoun (GR-7), American spelling (1.14). Rule 3.7 is the
fastest correction of all: if an approved verb names the action, use that verb, not a noun.

Rules 1.5 and 1.12 permit the technical nouns and technical verbs of this subject field.
"Connect IQ", "Monkey C", "watch face", "data field", "glance", "Body Battery", "Bluetooth Low
Energy", "GATT characteristic", "chirp", "range-Doppler" and "presence detection" are not defects.

## Step 4. Run the gate

```bash
python .claude/skills/ste-writing/scripts/ste_check.py PATH.md                    # 25-word descriptive limit
python .claude/skills/ste-writing/scripts/ste_check.py PATH.md --mode procedure   # 20-word procedural limit
python .claude/skills/ste-writing/scripts/ste_lookup.py ensure perform
```

Both scripts use only the Python standard library. The gate reads prose. It skips fenced blocks
and table rows, so it does NOT read a mermaid label and it does NOT read a table cell. A verdict
file is mostly tables and diagrams, which is where the gate is blind. Write those short and plain
by hand, then read them yourself.

Mark a verbatim region with `<!-- ste-check: off -->` and `<!-- ste-check: on -->`.

## When a table becomes HTML or a PDF

Size the columns by `report-standard` section 5. Render the page and look at it.

## Red flags

| The thought | The reality |
|---|---|
| "This is only a chat reply" | A chat reply is a document for the user. The two halves bind. |
| "The history shows my work" | Rule 1 of step 2. History stays out of the document. |
| "A paragraph reads better than a table" | Table-first. Prose is for the one-line map. |
| "The table is fine, the pipes line up" | Source alignment says nothing about the page. Render it and look. |
| "The sentence reads well at 40 words" | Rule 6.3 gives a number, not an opinion. Divide it. |
| "This word is technical, so it is approved" | Only if it fits a category in rule 1.5 or 1.12. Look it up. |
| "The gate is clean, so the document is done" | The gate cannot read tables, diagrams, or the judgment rules. |
| "Styled mermaid looks better" | It is unreadable in dark mode. |
| "STE will make the claim weaker" | STE changes wording only. A weaker claim is a different defect. |
| "The pitch should be in STE too" | No. The pitch is spoken persuasion. `presentation` owns it. |

## References

| File | What it holds |
|---|---|
| `references/01_rules.md` | all 57 STE rules of part 1 and the 8 general recommendations |
| `references/02_replacements.md` | the recurring-errors table, the approved verbs, the project word list |
| `references/03_scope_and_carveouts.md` | where the standard binds, where it stops, how it meets the other skills |
| `references/04_document_formats.md` | the state-summary skeleton, and the default for every other document |
| `data/ste_dictionary_index.json` | 2240 dictionary entries with page numbers, for `ste_lookup.py` |
| `scripts/ste_check.py` | the mechanical gate |
| `scripts/ste_lookup.py` | the dictionary lookup |
