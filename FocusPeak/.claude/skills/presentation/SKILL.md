---
name: presentation
description: "Use for the pitch of the Tech Thursday x Garmin hackathon: 3 minutes plus questions on Saturday 2026-11-14, pitching starts at 4 pm. Trigger on pitch, presentation, slide deck, slides, demo script, demo video, rehearsal, speaker notes, judges, Q and A preparation, or any file under pitch/. Covers the story mapped to the five judging criteria, the live-demo plan with fallbacks, the five slide principles (Phillips) and the deck_build.py and deck_check.py tools for a .pptx. Not for written reports (report-standard) or text on the watch screen (hackathon-code-standard)."
---

# Pitch skill: Tech Thursday x Garmin hackathon

## Facts that bind (organizer messages)

| Item | Value |
|---|---|
| Length | 3 minutes, then questions from the judges |
| When | Saturday 2026-11-14, pitching starts at 4 pm |
| Format | Free. The organizers said the teams can be creative |
| Judging | Five criteria, 0 to 5 each (table below) |
| Constraint | Ideas may be prepared before the event. Nothing already built |

| Criterion | The judges' question |
|---|---|
| Problem-Solution Fit | How well does the solution address the objective outlined? |
| Execution and Deployment | Does it work? Is there a live deployment we can test? |
| User Experience and Design | How intuitive and well-designed is the solution? |
| Impact and Value | How effective is the solution at impacting people's habits? |
| Creativity and Approach | How creative or innovative is the solution? |

The problem statement comes out on the day. Read it twice and quote its words on the first slide:
Problem-Solution Fit is scored against "the objective outlined".

## The 3-minute structure

| Time | Beat | Criterion it serves |
|---|---|---|
| 0:00 to 0:20 | The habit problem: one person, one moment, one sourced number | Problem-Solution Fit, Impact |
| 0:20 to 0:35 | The idea in one sentence, in the words of the problem statement | Problem-Solution Fit |
| 0:35 to 1:45 | Live demo: one user story, end to end, on the watch or the simulator | Execution, User Experience |
| 1:45 to 2:20 | How it changes the habit: the trigger, the action, the reward, and what the app measures | Impact and Value |
| 2:20 to 2:45 | What is new in the approach (data, sensor, interaction or hardware) | Creativity |
| 2:45 to 3:00 | How the judges can try it now, then one closing line | Execution and Deployment |

## Demo plan

| Level | What | Ready by |
|---|---|---|
| Primary | The app on a real watch (sideloaded `.prg`) under a document camera, or the Connect IQ simulator mirrored on the projector | Code freeze, at least 45 minutes before the pitch |
| Fallback 1 | A 30 to 60 second screen recording of the same user story | 3:30 pm |
| Fallback 2 | Screenshots of each screen in the deck | 3:30 pm |
| Hands-on for judges | One device that a judge can hold, with the app open on its first screen | Pitch time |

Rehearse the demo path three times end to end. Never show a feature that does not work. Say what
is simulated ("demo mode plays recorded data") before a judge asks.

## Slide design (five principles)

Source notes and the reason for each limit: `references/phillips_five_principles.md`.

| # | Principle | Rule in one line |
|---|---|---|
| 1 | One message | Notes start with `Message: <one sentence>`. The heading or the focal item says it |
| 2 | Working memory | Phrases on the slide, sentences in the speaker notes |
| 3 | Size | The key item is the biggest content text, 28 to 32 pt. Nothing below 18 pt |
| 4 | Contrast | Dark background, light text, one focal item in the accent color. No grey text |
| 5 | Objects | At most 6 objects in the content area. More slides is fine |

A 3-minute pitch fits 4 to 6 slides around the demo. No em-dashes on slides.

## Questions to prepare (one short answer each, in `pitch/qa.md`)

| Criterion | Likely question |
|---|---|
| Problem-Solution Fit | Who exactly is the user, and why does the problem matter to Garmin users? |
| Execution and Deployment | What is real and what is simulated? Can we install it? |
| User Experience and Design | How many button presses to the core action? What does the glance show? |
| Impact and Value | How do you know it changes a habit? What would you measure in a 30-day trial? |
| Creativity and Approach | What exists already, and what is different here? |
| Any | What would you build next with one more week? |

## Tools

All files live in `pitch/` at the repo root: the deck, `talk_notes.md`, `qa.md`, the demo video.

```bash
# new 16:9 dark deck: cover, N content slides, closing slide
uv run --with python-pptx python .claude/skills/presentation/scripts/deck_build.py new pitch/pitch.pptx --slides 5
# design gate: must report 0 FAIL before the pitch
uv run --with python-pptx python .claude/skills/presentation/scripts/deck_check.py pitch/pitch.pptx
# PDF and one JPEG per slide (needs LibreOffice)
uv run --with python-pptx python .claude/skills/presentation/scripts/deck_build.py render pitch/pitch.pptx
```

`deck_check.py` defaults to the dark theme with the accent `FF8C42`. Use `--theme light` for a
white deck and `--accent RRGGBB` for another accent. A deck made in Google Slides or PowerPoint
can be exported to `.pptx` and checked the same way.

## Working rules

1. **Keep the link for every statistic** in the speaker notes. Judges can ask where a number comes
   from. `ASG-audit` is the quick check.
2. **One owner for the deck file.** Others send changes to the owner.
3. **Save, do not overwrite.** `pitch_v2.pptx`, `pitch_v3.pptx`. The earlier file stays.
4. **Time it.** Rehearse with a timer. Cut words, not the demo. Stop at 2:50 in rehearsal.
5. **Speaker notes hold the script.** Each content slide's notes start with `Message:`.

## What NOT to do

- Do not spend more than 20 minutes on slides before the demo path works.
- Do not read slides aloud. Slides hold phrases, the speaker holds the sentences.
- Do not claim a habit effect that the app does not measure. Say "we expect" and name the measure.
