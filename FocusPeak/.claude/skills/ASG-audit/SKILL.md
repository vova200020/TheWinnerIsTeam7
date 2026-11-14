---
name: ASG-audit
description: "Quick fact-check for the hackathon. Use before a number, a health or habit statistic, a Garmin feature or Connect IQ API claim, or a hardware spec goes on a slide, into the text of the app, or into a findings file that the team will rely on. Trigger on fact-check, verify, double-check, is this true, where is this from, can we claim this, source for this. Fast and practical: open the real source, confirm it says exactly this, keep the link. Not an academic audit."
---

# Fact-check (hackathon version)

Nothing false goes on a slide, into the app, or into a findings file. A judge can ask "where does
that number come from?", and a wrong assumption about an API or a pin voltage can cost hours.

## What to check, and where

| Claim | Check it against |
|---|---|
| A statistic in the pitch (for example, how many adults miss their sleep or step goals) | The page that published it: a health agency, a survey, a paper abstract |
| A Garmin feature or Connect IQ API fact (what the Fenix 7 Pro supports, a permission, a limit) | The API pages on developer.garmin.com, the SDK `doc/` folder, the device files in `%APPDATA%\Garmin\ConnectIQ\Devices\fenix7pro\` |
| A hardware spec (voltage, pinout, range, data rate) | The datasheet or user guide in `hardware/*/docs/` |
| A claim about another app, a Garmin product or an earlier hackathon | The page itself |

## How: three questions per claim

1. **Is the source real and the right one?** Open the page or the document itself, not a summary
   and not memory.
2. **Does it say exactly this?** The same number, the same unit, the same device or group of people.
3. **Does it apply to us?** Connect IQ facts for SDK 9.1.0 and API level 5.2 (Fenix 7 Pro). Hardware
   facts for the exact board revision.

If one answer is no: correct the claim, make it narrower ("in one 2024 survey"), or drop it.

## Rules

| Rule | Why |
|---|---|
| Never invent a number, a source, a quote or a link | A judge or a teammate will check it |
| Check every number that an AI tool or a teammate adds | Generated text often carries numbers with no source |
| Avoid "first", "only" and "no app does this". Say what you looked for and did not find | Judges know the market |
| Keep the link next to the claim: in the speaker notes for a slide, in a comment for app text, on the line itself in a findings file | Anyone can check it again in seconds |
| Time-box each claim to about 10 minutes. If it takes longer, use a claim that is easy to confirm, or drop it | It is a one-day event |

## Output

No separate report. For the pitch, keep a short `pitch/sources.md`:

| Claim | Link | Status |
|---|---|---|
| The claim as it appears on the slide | URL, or document and page | ✅ confirmed, ⚠️ narrowed, ❌ dropped |
