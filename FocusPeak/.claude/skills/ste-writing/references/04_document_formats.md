# Document formats

The STRUCTURE half of this skill.

## 1. State summary or answer file (`START_HERE.md`, an answer `.md`)

| Section | What goes in it |
|---|---|
| Title | The subject and the date |
| One-line map | A blockquote that says what the file holds |
| 0. Status table | One row per area or question, with a **"your open action"** column |
| 1 to N | One section per question. Each section starts with its result table, then short notes |
| Glossary | Needed when the file uses more than 6 acronyms |

| # | Rule |
|---|---|
| 1 | Latest state only. No history of changes inside the document. The one exception is the change-sync ledger in `START_HERE.md` |
| 2 | Table-first. Every enumerable set is a table. Checklists as GitHub-flavoured Markdown checkboxes |
| 3 | Plain language. Explain each technical term once, at its first use |
| 4 | Visuals: a mermaid `flowchart` with no style, fill or colour directives, plus a plain-ASCII twin. HTML pages use inline SVG (`report-standard`) |
| 5 | Give the link for a fact that a teammate may need to check: a URL, or the document and the page. No other citation format |
| 6 | No em-dashes. Use a colon, a comma or parentheses |

## 2. Every other document

The default for a report, a findings file, a handout, a plan, or a note:

1. A title that names the subject and the date.
2. One line that says what the document is and what it is not.
3. The answer FIRST, before the method.
4. Tables for every enumerable set.
5. A short note below a table, when a table cell cannot carry it.

Then the wording rules of `01_rules.md`, then the gate.

## 3. Formats that a different skill owns

Do not invent a format that already exists. Read the owner first.

| Document | Owner |
|---|---|
| The pitch deck, script and demo plan | `presentation` |
| A PDF report with figures | `md-to-pdf` (user-level skill) |
| Code, comments and text on the watch screen | `hackathon-code-standard` |
| A report or an HTML page | `report-standard` (user-level skill) |
| A fact-check list for the pitch | `ASG-audit` |
| A change-sync ledger row | The rules at the top of `START_HERE.md` |

This skill still sets the WORDING inside each of them. It does not set their structure.
