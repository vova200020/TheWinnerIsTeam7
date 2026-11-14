# FocusBar (watch side)

This is the Connect IQ part of [../focus-app-spec.md](../focus-app-spec.md). It is built for the fēnix 7 Pro and covers MVP milestones 1–4 (§9). The phone companion and the backend are not included.

```
FocusBar/
├── shared/   Focus score + storage/date helpers + bar drawing (used by both)
├── face/     Watch face: time, date, 270° focus arc, state         (spec §2)
├── app/      Device app: glance, background prompt, focus session,
│             break nudges, self-report, XP/awards, HR unlock      (spec §2.2, §3, §5, §7)
└── ios/      iPhone companion: Screen Time blocking, unlock flow,
              #focus calendar, focus map + friends (mock)          (spec §4–§7) → ios/README.md
```

## Build and run

```sh
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY=../../developer_key.der            # generated locally, git-ignored

cd app  && "$SDK/bin/monkeyc" -f monkey.jungle -d fenix7pro -o bin/FocusBar.prg  -y $KEY -l 3
cd ../face && "$SDK/bin/monkeyc" -f monkey.jungle -d fenix7pro -o bin/FocusFace.prg -y $KEY -l 3

"$SDK/bin/connectiq" &                                   # simulator
"$SDK/bin/monkeydo" app/bin/FocusBar.prg fenix7pro       # or face/bin/FocusFace.prg
```

To install on a watch, copy both `.prg` files to `GARMIN/APPS/` over USB.

## Demo mode (turn this on for the pitch)

Neither the simulator nor a brand-new watch has stress or Body Battery history, so the score stays at "Learning you…".
To get scripted data, turn on **Demo mode**. In the app it's under hold UP → Demo mode, or in the settings. The face has its own setting.

With demo mode on:
- The readiness score follows a 30-minute wave, so the face turns green and the window opens on cue.
- Sessions are compressed: 30 s of calibration, then focus dips at about 90 s, and the "Take 5?" break nudge fires about 2 minutes in.
- To trigger the background prompt now, use **Simulation → Background Events → Temporal event** in the simulator.

## Demo script (spec §9)

1. The face is green: "Focus window open".
2. The watch buzzes: "Focus window open (78). Start a session?"
3. Press START, choose Coding and 50 min. The session starts recording; detox level comes from settings (default Deep).
4. Open hold UP → **HR unlock (demo)**. Do jumping jacks: the ring fills while your HR is above the target, and the watch sends `unlock_granted`.
5. Focus dips → "Take 5?" → a guided breathing break, with the timer paused.
6. End & save → rate it 1–5 → summary with XP, the weekly goal, and awards.

## How the score works

| Where | Signals | Formula |
|---|---|---|
| Face / background (every 5 min) | Stress (−), Body Battery (+), HR (−) from `SensorHistory` | Each signal's z-score is measured against the user's own recent history (Welford mean/sd, last ≤600 samples). Weights are 0.35 / 0.20 / 0.15, renormalised over the signals that are present. Score = 50 + 15·raw, then smoothed with an EMA (α 0.3). |
| Window | The user's own 70th percentile of the last 24 h (histogram, minimum 55) | The window opens after 2 ticks (10 min) at or above that value. |
| Live session (every 10 s) | RMSSD from `heartBeatIntervals`, HR, accelerometer stillness (inverted U) | The score starts from the pre-session readiness score, and live deviations are measured against the first 3 minutes of the session. |

Each session is recorded as an activity with a custom FIT field `focus_score` (per second) and `avg_focus` (per session), so it appears in Garmin Connect.

Background prompts are rate-limited. There is at most 1 every 90 minutes, and none during the user's configured sleep hours, during a running session, or when the user has chosen "Snooze prompts today".

## HR unlock safety (spec §5.2)

- The target is max(resting + 35, 100) bpm, capped at 60% of age-predicted max HR.
- The hold is 45 s, plus 15 s for each repeat unlock that day. The ring pauses below target and never resets.
- If there is no HR signal for 10 s, or the user prefers it (the `unlockAlt` setting), the user can do a 60-second breathing exercise instead.
- The emergency bypass belongs to the phone app.

## Phone protocol (spec §4.2), implemented on the watch side

Sent by the watch: `session_start`, `session_end`, `unlock_granted`. Handled when received: `unlock_request`.
Without a phone companion these messages fail silently, and the watch keeps working on its own.

## Not built yet

- The **backend** (spec §8). The iPhone companion in `ios/` covers the phone side; its map and friends use mock data.
- The **watch face doesn't show the weekly goal**. Faces and apps have separate storage, so the face can't read it. The app's glance and home screen show it. A future fix is to publish it as a CIQ complication.
- **Time-of-day baseline buckets** (§1.2) and **weekly weight recalibration** (§1.4). Self-reports are stored in `reports` so the phone can do the calibration.
- **Devices:** only `fenix7pro` is in the manifests. Add the 7S Pro and 7X Pro in SDK Manager to build for them; the layout already scales from `dc.getWidth()`.
