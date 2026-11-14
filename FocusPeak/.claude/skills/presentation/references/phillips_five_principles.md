# Source notes: Phillips, five slide-design principles

The five slide rules in the `presentation` skill come from this talk. This file records what the
talk says, in paraphrase, and how each point became a rule for the pitch deck.

| Field | Value |
|---|---|
| Talk | David JP Phillips, "How to avoid death by PowerPoint", TEDxStockholmSalon, about 18 minutes |
| Video | <https://www.youtube.com/watch?v=Iwpi1Lm6dFo> |
| Transcript read | <https://singjupost.com/how-to-avoid-death-by-powerpoint-david-jp-phillips-at-tedxstockholmsalon-transcript/>, read in full on 2026-10-05 |
| Type of source | A practitioner talk. Use it as a design convention |

## What the talk says, and the rule it gives

| # | Principle | What the talk says (paraphrase) | Our rule |
|---|---|---|---|
| 1 | One message | Two messages on a slide divide attention, like a person who hears their name in another conversation at a party | One `Message:` sentence per slide. The heading or the focal item says it |
| 2 | Working memory | Text sentences on the slide while the speaker talks: the audience keeps almost nothing (the redundancy effect). Put the text in the notes field. Keep short text and an image on the slide | Phrases only. Sentences go in the speaker notes and `pitch/talk_notes.md` |
| 3 | Size | The eye goes to moving items, signal colours (red, orange, yellow), high-contrast items, and big items. Most templates make the heading the biggest item, but the heading is seldom the most important part | The key item is the biggest content text, 28 to 32 pt |
| 4 | Contrast | Contrast controls focus. Show one item, then move the contrast to the next item. A large table becomes readable when contrast marks the part that matters. Prefer dark backgrounds, so the speaker has the most contrast in the room | Dark background, light text, one focal item in the accent colour. Lists that need explanation are builds |
| 5 | Objects | Six objects is the limit. At seven or more the audience must count, which takes much more time and effort than seeing. More slides is not the problem; more objects per slide is. Do not show "page 12 of 95" | At most 6 objects in the content area. Plain slide number only |

At the end, the talk tests the audience with five questions. The answers are: one message, contrast
and size for focus, no sentences while speaking, dark backgrounds, and six objects.

## Where our rule is stricter or different, and why

| Our rule | Talk | Reason |
|---|---|---|
| At most 5 bullets of 7 words | 6 objects | A 3-minute pitch has no time for a slide that must be read |
| A table counts one object per row | Large tables are acceptable if contrast guides the eye | A row is what the eye must count. The 6-row limit keeps the table readable at a glance |
| Static build slides, not animations | Uses PowerPoint animation to move the contrast | Static copies survive the PDF export, and `python-pptx` can make them |
| The live demo is the centre of the pitch | Not covered | The judges score "does it work" and "is there a live deployment we can test" |

## Test record of `deck_check.py` (2026-11-13)

| Test | Result |
|---|---|
| `deck_build.py new` without a template, 3 content slides | 5 slides, 0 FAIL, 0 WARN |
| The same deck with one planted bad slide (7 sentence bullets, 14 pt, grey text) | 6 FAIL: objects, bullets, words per bullet, full sentence, text size, contrast |
