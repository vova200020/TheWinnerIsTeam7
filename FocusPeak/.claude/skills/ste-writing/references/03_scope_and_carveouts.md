# Scope: where this skill binds, and where it stops

This skill governs the documents and the messages generated in this repository. It sets their
structure (`04_document_formats.md`) and their wording (`01_rules.md`). Nothing outside this
repository is its work.

## Why a scope decision is necessary

ASD-STE100 is a controlled language for technical documentation in aerospace and defense. It
does two things at once: it limits the sentence, and it limits the dictionary. The first travels
to every subject field. The second travels only through rules 1.5 and 1.12, which let a subject
field bring in its own technical nouns and technical verbs.

## The scope table

| What the assistant writes | Does STE bind? | Limit | Note |
|---|---|---|---|
| A chat reply | Yes | 25 words | Answer first. The most frequent case |
| `START_HERE.md`, `MAP.md`, a findings file, a report, a plan | Yes | 25 words | Run the gate before the file is finished |
| A runbook, a set-up, wiring or flashing step, a checklist, a command sequence | Yes | 20 words | Procedural writing. Imperative form |
| A note inside a procedure | Yes | 25 words | Rule 5.5. Never an instruction |
| A safety instruction (power, wiring, battery) | Yes | 20 words | Rule 7. Command first, then the risk |
| A commit message, a code comment | Yes, for the prose | 25 words | The code itself is exempt |
| The pitch script, slide text, the demo voice-over | No | - | `presentation` owns it |
| Text on the watch screen | No | - | `hackathon-code-standard` section 7 owns it |
| A sentence that the user or a teammate wrote | No | - | Never rewrite it without a request |

### The two halves inside one document

| The structure half asks for | The wording half gets there too |
|---|---|
| Table-first: every enumerable set is a table | Rule 4.3, which sends complex text to a vertical list |
| Prose only for the one-line map and short notes | Rules 6.3 and 6.6, which cap the sentence and the paragraph |
| Plain language a teammate from another field can follow | Rules 1.1 and 9.2, which limit the words to the approved set |
| Latest state only, no change history | Nothing in STE. This rule stands on its own |
| Mermaid `flowchart` unstyled, no mindmap, no timeline | Nothing in STE. This rule stands on its own |

Two cautions. First, the gate skips fenced code, so it does NOT read a mermaid label. Write each
label short and plain by hand. Second, the gate skips table rows, so a table cell can hide a long
sentence or a word that is not approved. Read the tables yourself.

## The carve-outs

The assistant does not apply STE to these, and does not change them:

1. **A quotation.** Rule 8.6 counts quoted text as one word. Changing a quote changes its meaning.
2. **An identifier:** a URL, a part number, a datasheet or app-note number, a device id.
3. **Code, a file path, a command, a formula, a variable name, a table of numbers.**
4. **A technical noun or technical verb of this subject field.** Rules 1.5 and 1.12 permit them.
   "Connect IQ", "Monkey C", "watch face", "glance", "Body Battery", "GATT characteristic",
   "range-Doppler" and "presence detection" all enter through this door. They are not defects.
5. **The pitch script, slide text and text on the watch screen.** The `presentation` and
   `hackathon-code-standard` skills own them.

## The conflicts, and how each resolves

| # | STE says | The project says | Resolution |
|---|---|---|---|
| 1 | Rule 1.14: use American English spelling. | The event is in Calgary, and the team may prefer Canadian spelling. | Use American spelling by default. If the team picks Canadian spelling for shared text, run the gate with `--canadian`. |
| 2 | GR-7: "he" and "she" are not permitted. | Documents name roles (the user, the team, the judges). | No conflict. Never use a gendered pronoun for a person. |

## How this skill works with the other project skills

1. The task skill owns the structure of its own output: `report-standard`, `presentation`,
   `hackathon-code-standard` or `md-to-pdf`.
2. `ste-writing` shapes the wording. For a state summary or an answer `.md` it owns the structure
   too, because no other skill does.

STE never changes the meaning. If an approved word would make a statement stronger, weaker or
different (rule 9.1), rebuild the sentence and keep the meaning.

## What the assistant must NOT do with this skill

- Do not rewrite existing files into STE without a request.
- Do not drop information to fit the 25-word limit. Divide the sentence instead.
- Do not report that a text is "in STE" because the gate is clean. The gate cannot do rules 1.5,
  2.1, 5.5, 6.5, or 9.2.
- Do not treat a WARN as a defect without reading the line. The passive-voice and phrasal-verb
  checks are heuristics.
- Do not block the team on wording. At the event, a useful text now beats a perfect text later.
