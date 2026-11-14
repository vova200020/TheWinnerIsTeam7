# FocusBar: Product and Build Spec

> A Garmin watch face plus app that reads your body to tell you when focusing will come easily. It then protects that window with a digital-detox session, nudges you to take breaks, and turns the habit into a game you play with friends.

Working name: **FocusBar**. Target: fēnix 7 Pro family (same device notes as `compass-hands-spec.md`).

---

## 0. Reality check: what Garmin can and can't do

Read this first. Several features in the brief can't run on the watch alone, so the system needs **four parts**.

| Feature | Watch alone? | Where it actually lives |
|---|---|---|
| Live focus bar on watch face | ✅ (with limits) | Watch face, using `SensorHistory` + background |
| Raw IMU (accelerometer) for fidget/stillness | ⚠️ Not in watch faces | Device app during sessions (`Sensor.registerSensorDataListener`) |
| HRV (beat-to-beat) | ⚠️ Device app only | Session app. The face uses Garmin's **Stress** score, which is HRV-based |
| Pulse Ox, skin temperature | ⚠️ History only, sparse | `SensorHistory.getOxygenSaturationHistory()` / `getTemperatureHistory()`. These are context signals, not live ones |
| "Start a session?" prompt from the face | ✅ | `Background.requestApplicationWake("Focus window open — start?")` |
| Watch DND / focus mode toggle | ❌ No CIQ API (read-only `DeviceSettings.doNotDisturb`) | Ask the user to enable it, or use a phone-side focus mode |
| Phone DND, app blocking, contact allow-list | ❌ | **Phone companion app** (Android: DND policy + UsageStats/Accessibility; iOS: Screen Time API + Focus filters) |
| Calendar-scheduled sessions | ❌ No calendar API in CIQ | Phone companion reads the calendar → sends to watch via `Communications` |
| Community focus map, friends, challenges | ❌ | **Backend** (via phone, `makeWebRequest`) |
| HR-raise to unlock apps | ✅ measuring HR on the watch | Watch verifies, then tells the **phone app** to unlock |

### Architecture

```
┌──────────────┐   background    ┌─────────────────┐
│  Watch Face  │ ───wake prompt─▶│ Watch App        │
│  focus bar   │                 │ session, HRV,    │
│  (low power) │◀──score cache───│ IMU, unlock, nags│
└──────┬───────┘   Storage       └────────┬────────┘
       │ makeWebRequest / transmit        │ Communications.transmit
       ▼                                  ▼
┌──────────────────────────────────────────────────┐
│ Phone Companion (Android first)                   │
│ DND · app blocking · allow-list · calendar · map  │
└──────────────────────┬───────────────────────────┘
                       ▼
            ┌─────────────────────┐
            │ Backend              │
            │ focus map · social · │
            │ challenges · awards  │
            └─────────────────────┘
```

---

## 1. Focus Score (the backbone)

### 1.1 Signals

| Signal | Source | Direction | Weight (start) | Notes |
|---|---|---|---|---|
| Stress (HRV-derived, 0–100) | `SensorHistory.getStressHistory()` | lower = better | **0.35** | Best cheap proxy for calm-alert state |
| HRV RMSSD | `heartBeatIntervals` (session app only) | higher than baseline = better | replaces stress in sessions | 60 s rolling window |
| Heart rate vs. resting | `getHeartRateHistory()` / `Sensor.Info.heartRate` | near resting = better; very high = worse | 0.15 | Exclude during and right after activities |
| Stillness / fidget | IMU (session) or step cadence (face) | moderately still = better | 0.15 | Too still for too long may mean drowsy. Use an inverted-U |
| Body Battery | `getBodyBatteryHistory()` | higher = better | 0.20 | Readiness/energy |
| Skin temperature delta | `getTemperatureHistory()` | stable vs. baseline = better | 0.05 | Context only. Large deviation may mean illness |
| Pulse Ox | `getOxygenSaturationHistory()` | gate only | 0.10 | Sparse readings. Flag only if well below the user's baseline |

> **Honesty note for the pitch:** there's no validated "focus sensor." The defensible claim is *physiological readiness to focus*, personalised and then **calibrated by the user's own self-reports** (see 1.4). Stress/HRV and Body Battery carry most of the signal. SpO₂ and temperature are supporting context.

### 1.2 Personal baseline
- **Warm-up:** the first 7 days collect data only. The face shows "Learning you… day 3/7."
- Keep a **rolling 14-day baseline** per signal, split into **4 time-of-day buckets** (morning, midday, afternoon, evening). Focus is circadian.
- Store mean + standard deviation (or median + MAD) per signal per bucket.

### 1.3 Score formula
```text
for each signal s:
    z_s = (value_s − baseline_mean_s) / baseline_sd_s
    z_s = clamp(z_s, −3, 3) · direction_s          // flip so + = good
raw   = Σ weight_s · z_s   (renormalise weights over available signals)
score = round(50 + 15 · raw)  clamped 0–100        // 50 = your normal
smooth with EMA (α = 0.3) to avoid a jumpy bar
```
- Missing signals are skipped and the weights renormalised. Null-check everything (see `monkey-c-pitfalls.md` §3).
- Exclude windows during or ≤30 min after recorded activities and during sleep.

### 1.4 Self-calibration loop (what makes it personal)
- At the end of each session, ask: **"How focused were you? 1–5"** (one button press).
- Weekly, run a tiny regression of self-report against signal z-scores and **nudge the weights** (bounded ±0.05 per week). Do this on the phone or backend, not the watch.
- Show the user: "Your focus tracks most with **low stress** and **high Body Battery**."

### 1.5 Thresholds
| State | Rule | Face colour |
|---|---|---|
| Low | score < 40 | gray |
| Normal | 40–64 | white |
| **Focus window** | score ≥ user's **70th percentile** for ≥ 10 min | green + glow |

---

## 2. Watch face

### 2.1 Layout (260×260 round MIP)
```
        ┌──────────────┐
        │    10:52     │   time (large)
        │  Sat Nov 14  │
        │ ▓▓▓▓▓▓▓░░░ 72│   FOCUS BAR (arc or horizontal) + score
        │ ● window open│   state label
        │ 🔥 4/5 days  │   weekly focus goal (forgiving streak)
        └──────────────┘
```
- **Focus bar:** a 270° arc around the bezel works well on round screens. A tick marks the user's threshold.
- Update the score **once a minute** in `onUpdate()` from cached values. Heavy computation stays out of the face.

### 2.2 Background service (`(:background)`)
- **Temporal event every 5 min** (the CIQ minimum).
- Reads `SensorHistory`, computes the score, writes `Storage` (`lastScore`, `scoreTrend[]`), and returns via `Background.exit()`.
- If the focus window opens, there's no session running, and the user is not muted:
  `Background.requestApplicationWake("Focus window open (78). Start a session?")`
- **Rate limit:** max 1 prompt per 90 min, none during sleep or activities, and a "snooze today" option.

### 2.3 Face constraints
- No timers, no vibration, no raw sensors in the face itself. The background service does the work.
- Keep background memory small. Store compact arrays, not dictionaries.

---

## 3. Focus Session (watch app)

### 3.1 Entry points
1. Accept the wake prompt from the face.
2. **Scheduled:** the phone reads calendar events tagged `#focus` (or a chosen calendar) and pushes them to the watch. The watch wakes the app at start time via a background temporal event.
3. **Manual:** launch from the app list, or a hotkey or shortcut.

### 3.2 Session setup (2 screens max)
- **Tag:** Studying · Journaling · Book writing · Coding · Reading · Custom
- **Length:** Open / 25 / 50 / 90 min (default from the user's average for that tag)
- **Detox level:** (phone-enforced, see §4)
  - 🟢 Light: DND on
  - 🟡 Medium: DND + block distracting apps
  - 🔴 Deep: DND + block apps + contacts allow-list only

### 3.3 During the session
- Record like a workout. Use `ActivityRecording.createSession()` with a custom sport/sub-sport (e.g. `SPORT_GENERIC`) so the session appears in Garmin Connect. Add **custom FIT fields** for focus score per minute.
- Live signals: HR, HRV (RMSSD from `heartBeatIntervals`), accelerometer stillness at 1 Hz summarised every 10 s.
- Screen: big elapsed time, live focus bar, tag. Minimal by design.
- Save GPS once at start (one-shot fix) for the community map. Don't track continuously (battery and privacy).

### 3.4 Break nudges
Trigger a gentle vibration plus a "Take 5?" screen when **either** happens:
- the focus score drops ≥ 15 points below the session's first-10-min average and stays there 5 min, **or**
- the session passes the user's personal "fade point" (learned average time to decline; default 50 min).

Options: **Break 5 min** (guided breathing or a stretch, with the timer paused) · **Keep going** (snooze 15 min) · **End**.

### 3.5 Session end
- Self-report 1–5 (feeds §1.4)
- Summary: duration, avg score, peak window, breaks taken
- XP and award progress (§6)

---

## 4. Digital detox (phone companion)

### 4.1 Platform reality
| Capability | Android | iOS |
|---|---|---|
| Toggle DND | ✅ `NotificationManager` with policy access | ❌ Can't toggle Focus programmatically. Use a **Focus filter** + Shortcuts automation, or ask the user to enable it |
| Block apps | ✅ UsageStats + overlay / Accessibility service | ✅ **Screen Time API** (FamilyControls / ManagedSettings). Needs Apple entitlement approval |
| Contacts allow-list | ✅ DND priority senders policy | ⚠️ Configured in the user's Focus settings |

**Recommendation:** build **Android first** for the hackathon. Everything is controllable there.

### 4.2 Message protocol (watch ⇄ phone via `Communications.transmit` / Mobile SDK)
```json
{ "t": "session_start", "tag": "studying", "level": "deep", "len": 50 }
{ "t": "session_end", "dur": 2930, "avg": 71, "self": 4 }
{ "t": "unlock_request", "app": "com.instagram.android" }    // phone → watch
{ "t": "unlock_granted", "app": "com.instagram.android", "mins": 5 } // watch → phone
{ "t": "schedule", "sessions": [ { "start": 1763143200, "len": 50, "tag": "writing" } ] }
```

---

## 5. HR-to-unlock ("earn your scroll")

### 5.1 Flow
1. The user opens a blocked app on the phone and sees a "Locked — earn it on your watch" screen.
2. The phone sends `unlock_request` and the watch app opens the **Unlock Challenge**.
3. The watch shows a target: **raise HR to `max(resting + 35, 100)` bpm and hold for 45 s**.
4. A progress ring fills only while HR ≥ target. Dropping below pauses it (it doesn't reset).
5. On success, the watch sends `unlock_granted` and the app is unlocked for 5 min. Each repeat unlock in the same session costs **+15 s more hold**.

### 5.2 Safety rules (non-negotiable)
- Cap the target at **~60% of age-predicted max HR**. Never require hard effort.
- Settings offer an **alternative unlock** (a 60 s breathing exercise or a typed reflection). This is needed for accessibility, heart conditions, and beta-blocker users.
- An **emergency bypass** (calls, maps, banking) is always available with no challenge.
- Disable the challenge if HR data is unreliable (null or a poor optical signal).

---

## 6. Community focus map

### 6.1 Data collected per session (opt-in)
`{ geocell, tag, duration, avg_score, hour_bucket, weekday }`. **No raw coordinates leave the phone.**

### 6.2 Privacy design
- Snap location to a **geohash-7 cell (~150 m)** on the phone before upload.
- Show a cell only when **≥ 5 distinct users** have logged sessions there (k-anonymity).
- Never show home or residential cells. Exclude cells near the user's frequent overnight location.
- Profiles show stats, not places.

### 6.3 Map features (phone app)
- Heatmap of average focus score by cell. Filter by tag and time of day.
- Cell card: "**Central Library** area · avg focus 74 · typical session 62 min · best 9–11 am · tags: studying, writing."
- "Find me a spot" ranks nearby cells by score × your tag × open now.

---

## 7. Gamification (built on `habit-design-playbook.md`)

| Mechanic | Design |
|---|---|
| **Weekly goal** | e.g. 5 sessions/week. Forgiving: the streak counts weeks, not days |
| **Comeback bonus** | Extra XP for the first session after a missed day (megastudy top performer) |
| **Milestones** | 1st session, 10 h focused, 50 sessions, first Deep session, first community cell discovered |
| **Awards (profile)** | Night Owl, Early Bird, Library Regular, Marathon (90 min unbroken), Explorer (5 cells) |
| **Weekly challenges** | Rotating, e.g. "3 Deep sessions," "Try a new focus spot," "Take every suggested break" |
| **Friends: friendly** | Shared group goal ("our team: 40 focus hours this week") |
| **Friends: competitive** | Weekly leaderboard on **focus minutes** or **consistency**, not raw score (scores are personal and not comparable between people) |
| **Never shame** | No "you broke your streak" messages. Show totals next to streaks |

---

## 8. Data model (backend)

```text
User(id, name, tz, settings, baseline_version)
Session(id, user_id, start, dur, tag, level, avg_score, self_report, geocell?, breaks)
ScoreSample(session_id, minute, score)                 // optional, for charts
Cell(geocell, n_users, n_sessions, avg_score, avg_dur, top_tags, best_hours)
Friendship(user_a, user_b, status)
Challenge(id, week, rule, reward)
UserChallenge(user_id, challenge_id, progress, done_at)
Award(user_id, award_code, earned_at)
```

---

## 9. Hackathon MVP (what to actually build)

| # | Milestone | Scope |
|---|---|---|
| 1 | Watch face with focus bar | Score from Stress + Body Battery + HR (history APIs). Simple baseline (median of the last 3 days) |
| 2 | Background prompt | 5-min temporal event + `requestApplicationWake` when the score crosses the threshold |
| 3 | Session app | Tag + length picker, live bar, HRV/IMU, break nudge on score drop, self-report at the end |
| 4 | HR unlock (demo) | Watch-side challenge working end to end. Phone side can be a mock Android screen |
| 5 | Android companion (thin) | DND on/off + block 1–2 apps + receive `unlock_granted` |
| 6 | Map + social (mocked) | Static seeded data in the phone UI or a web page. Show the concept, skip the real backend |

**Demo story:** face turns green, watch prompts, start a Deep session, phone goes quiet, open Instagram and it's locked, do jumping jacks to unlock, focus dips and the watch suggests a break, session ends, XP + award, map shows the best study spots nearby.

---

## 10. Open decisions
- [ ] **Phone platform:** Android-first (recommended) or iOS?
- [ ] **Score honesty in UI:** call it "Focus Readiness" instead of "Focus Score"?
- [ ] **Leaderboard metric:** minutes vs. consistency vs. sessions
- [ ] **Backend:** Firebase/Supabase (fast) vs. custom
- [ ] **Unlock alternative:** breathing vs. reflection prompt
