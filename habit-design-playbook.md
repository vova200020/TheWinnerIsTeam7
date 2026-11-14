# Garmin Habit App: Design Playbook

Actionable points drawn from successful Connect IQ apps and from research on habit formation.

---

## 1. Surface: where the habit shows up

- [ ] **Show progress in a watch face, glance, or complication first.** Treat the full app as secondary. People look at their watch face dozens of times a day, while a full app has to be opened on purpose.
  - *Evidence:* Goals (VAW.BE), a $1.99 ring watch face, was the #1 face on the Connect IQ Store in Oct 2026. Historically, the store's million-download items have been watch faces and data fields.
- [ ] **Show progress at a glance as a ring or bar that fills during the day.** It shouldn't need a tap or scroll.
  - *Evidence:* Users say they take late-night walks just to close a ring. Reviewers find rings more motivating than buzzing reminders.
- [ ] **Keep it lightweight on battery.** Reviewers notice battery drain and mention it, so test on low-end devices too.

## 2. Autonomy: let users own the goal

- [ ] **Let users choose what they track.** Don't hard-code one metric.
  - *Evidence:* Goals beats Apple's fixed three rings partly because users pick each ring's metric. In self-determination theory, autonomy predicts long-term adherence.
- [ ] **Let users set their own target, with a smart default.** For example, base it on a 2-week baseline.
- [ ] **Have users pick their habit during onboarding.** Self-chosen habits form faster than assigned ones (Lally 2010; 2024 meta-analysis).

## 3. Cues: anchor habits to triggers

- [ ] **Offer cue-based prompts ("After X, do Y")** using events the watch already detects:
  - waking up (sleep end)
  - finishing an activity
  - a time of day
  - arriving at or leaving a location
- [ ] **Have users write an implementation intention at setup:** "When [cue], I will [habit]." (Gollwitzer)
- [ ] **Suggest morning anchors.** Morning habits tend to automate faster than evening ones.
- [ ] **Avoid unanchored, random reminders.** A habit with an arbitrary time and no stable cue forms more slowly.

## 4. Streaks: use them without the downside

- [ ] **Use forgiving streaks.** Count 5 of 7 days as a success, or track a weekly streak instead of a daily one.
  - *Evidence:* In Lally 2010, missing one day had no material effect on habit formation.
- [ ] **Add a "repair" or "freeze" mechanic.** Repairable streaks soften the demotivating effect of a broken one (Silverman & Barasch, *JCR* 2023).
- [ ] **Never send "You broke your streak!" messages.** Highlighting a broken streak lowers later engagement, and people often abandon the activity.
- [ ] **Show a cumulative count next to the streak** ("142 days total"). It can't be lost, so a miss doesn't wipe out the user's sense of progress.
- [ ] **Consider capped or cycling streaks** (a weekly cycle, daily rings that reset) so the loss-aversion pressure doesn't keep growing.
- [ ] **When a break is due to illness or travel, say so.** Breaks blamed on oneself hurt more than breaks with an outside cause. Let users mark a day as "sick" or "travel."

## 5. Rewards: celebrate the comeback

- [ ] **Make the return after a miss the biggest reward moment** ("Welcome back! 🔥").
  - *Evidence:* In the Milkman megastudy (Nature 2021, n=61,293), the top performer of 54 interventions was a small bonus for returning after a missed workout.
- [ ] **Give small, immediate rewards on completion,** such as a vibration, an animation, or a ring closing. Small and immediate beats large and delayed.
- [ ] **Use milestones (7, 30, 66, 100 days) as "fresh starts"** that renew motivation.

## 6. Timeline: design for months, not weeks

- [ ] **Don't promise "21 days."** Tell users it takes about 2–5 months, and that this is normal.
  - *Evidence:* Lally 2010 found a median of 66 days (range 18–254). Exercise habits often take more than 90 days.
- [ ] **Plan an engagement boost around month 3,** when the novelty effect ends (Shin et al., Fitbit log data). Ideas: new goal tiers, a "level up," a yearly recap.
- [ ] **Shift from external motivation (badges, streaks) to intrinsic motivation over time.** Show users how they've changed ("Your resting HR dropped 4 bpm since you started").
- [ ] **Optional: add a monthly "automaticity" check-in** ("How automatic does this feel, 1–7?") to show progress beyond checkboxes.

## 7. Social: add light accountability

- [ ] **Offer optional buddy or group challenges.** Garmin Connect Challenges has 1M+ downloads and sits in the top 3 of the app chart.
- [ ] **Use social-norm messaging** ("Most people who start this keep going past week 4"). This was one of the top-performing interventions in the megastudy.
- [ ] **Keep social features opt-in.** Forced comparison can undermine autonomy and push people to abandon wearables.

## 8. Testing: don't trust intuition

- [ ] **A/B test reminder copy, streak rules, and reward timing.**
  - *Evidence:* In the megastudy, expert and lay forecasters failed to predict which interventions would work.
- [ ] **Measure retention after 4+ weeks, not just in the first weeks.** Only 8% of the megastudy interventions had measurable effects after the four-week program ended.
- [ ] **Track:** D7 / D30 / D90 retention, how often users come back after a miss, and which goal types users stick with.

## 9. Monetization

- [ ] **Use a free trial, then a low one-time price ($1.99–$4.99).** This is the pattern Goals uses for watch faces.
- [ ] **Account for Garmin's fees:** $100/yr developer fee plus 15% of each sale. Monetization only works on watches, not Edge devices.
- [ ] **Don't rely on donations below about 50k downloads.** Developers with around 1k downloads report less than $20 in lifetime donations.
- [ ] **Price for value.** A $4 niche data field (Ski Pin) sold 68–107 copies a month in season. Note: $3.99 and $4.99 both read as "about 5 bucks."
- [ ] **Ask for reviews outside of activities,** and point support questions somewhere other than reviews. Reviews skew negative because users mostly return to the store page when something breaks.

---

## Quick checklist for the hackathon MVP

1. A watch face or glance with 1–3 customizable progress rings
2. A cue-anchored habit set up through an "After X, I will Y" prompt
3. A forgiving weekly streak plus a cumulative total, with no broken-streak shaming
4. A "Welcome back" reward after a missed day
5. Onboarding copy that sets a 2–5 month expectation

---

## Sources

- the5krunner — [Connect IQ charts, Oct 2026](https://the5krunner.com/2026/11/02/goals-tops-garmins-watch-face-chart-for-october), [Best Garmin Apps](https://the5krunner.com/connect-iq/apps/)
- VAW.BE — [Goals Pro](https://garmin.vaw.be/community/day-101-goals-pro-garmin-watchface)
- Tom's Guide — [This $2 watch face is a game-changer](https://www.tomsguide.com/wellness/fitness-trackers/if-youre-moving-from-apple-to-garmin-youll-want-to-install-this-watch-face)
- Lally et al. (2010), *European Journal of Social Psychology* — [critical summary](https://www.thebehavioralscientist.com/articles/how-long-to-form-a-habit), [BPS digest](https://bps.org.uk/research-digest/how-form-habit)
- Silverman & Barasch (2023), *Journal of Consumer Research* — [On or Off Track](https://www.colorado.edu/business/faculty-research/2023/04/19/or-track-how-broken-streaks-affect-consumer-decisions)
- Milkman et al. (2021), *Nature* — [Megastudies improve the impact of applied behavioural science](https://mathematica.org/publications/megastudies-improve-the-impact-of-applied-behavioural-science)
- Shin et al. — [Beyond novelty effect: long-term activity tracker use](https://rcastoragev2.blob.core.windows.net/d6247f8fad72752d50d69587123854a6/PMC6952057.pdf)
- Garmin developer forums — [I Monetized My Ski App](https://forums.garmin.com/developer/connect-iq/f/showcase/430838/i-monetized-my-ski-app-here-s-what-happened)
