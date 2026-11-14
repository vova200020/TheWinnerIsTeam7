# FocusBar: checked facts for the pitch

Source: the FocusBar code on the build Mac, 2026-11-14. Paths are relative to `FocusBar/`.
"CONFIRMED" = read in the code. Values marked "computed" were derived from the code but not timed in a run.

## A1. Signals

| # | Signal (deck wording) | Read? (API, file:line) | Changes a score the user sees? | Status |
|---|---|---|---|---|
| 1 | Stress | `SensorHistory.getStressHistory`, `shared/FocusScore.mc:53` | Yes. Readiness score, weight 0.35, lower than your normal = better | CONFIRMED |
| 2 | Body Battery | `SensorHistory.getBodyBatteryHistory`, `shared/FocusScore.mc:56` | Yes. Readiness score, weight 0.20, higher = better | CONFIRMED |
| 3 | Heart rate | `getHeartRateHistory`, `shared/FocusScore.mc:59`; live `Sensor.Info.heartRate`, `app/source/FocusSession.mc:268` | Yes, twice. Readiness weight 0.15 (lower = better). Live session score weight 0.25 against the session's first minutes (`FocusSession.mc:321`). Also the HR unlock challenge | CONFIRMED |
| 4 | HRV (RMSSD from heartBeatIntervals) | `Sensor.registerSensorDataListener` `:heartBeatIntervals`, `FocusSession.mc:138-141`, `236-237` | Yes. Live session score only, weight 0.45 against the session's first minutes (`FocusSession.mc:317`) | CONFIRMED |
| 5 | Accelerometer stillness | Same listener, `:accelerometer` at 25 Hz, `FocusSession.mc:140`, `244` | Yes. Live session score only, weight 0.30, inverted U (`FocusSession.mc:326`, `374-385`) | CONFIRMED |
| 6 | GPS position | `Position.enableLocationEvents(LOCATION_ONE_SHOT)`, `FocusSession.mc:130`, stored `:177`, sent `app/source/EndFlow.mc:55` | **No.** One fix per session, stored and used for the phone's ~150 m map area and sharing. Context only | CONFIRMED |
| 7 | "Skin temperature" | `SensorHistory.getTemperatureHistory`, `shared/FocusScore.mc:66` | Yes, small. Readiness weight 0.05, "stable vs your normal = better" (`FocusScore.mc:110`). **Wording:** this is the watch's temperature sensor history, not a dedicated skin-temperature sensor | CONFIRMED (correct the wording) |
| 8 | Pulse Ox | `SensorHistory.getOxygenSaturationHistory`, `shared/FocusScore.mc:63` | Yes, as a **gate**. Weight 0.10, only lowers the score when below your normal, never raises it (`FocusScore.mc:111`). Accepts a reading up to 12 h old | CONFIRMED |
| + | Barometric pressure (not in the deck list) | `SensorHistory.getPressureHistory`, `shared/FocusScore.mc:72` | Yes, small. Readiness weight 0.05, unusually high **or** low for you = worse | CONFIRMED |

Note on the watch face: when the FocusBar app is installed, the face shows the app's published score (`face/source/FocusFaceView.mc:42`, via a complication). It only computes its own score if the app is missing (`face/source/FocusFaceApp.mc:25`). Both use `shared/FocusScore.mc`.

**Honest count: 8 signals change a focus score (stress, Body Battery, heart rate, Pulse Ox, temperature and air pressure for the readiness score, plus HRV and wrist stillness for the live session score), and 1 more (GPS) is read as context for the map.**

Against the deck's list of 8: 7 change a score, and GPS does not. Barometric pressure is a 9th signal that the deck does not list.

## A2. The score

| Statement | Verdict | Evidence |
|---|---|---|
| Readiness = 50 + 15 × weighted z-score against the user's own history, smoothed | CONFIRMED. z is capped at ±3. History = last ≤600 readings within 3 days, ≥10 needed. Smoothing is EMA α 0.3 (`FocusScore.mc:143`); demo mode skips it | `FocusScore.mc:75`, `:38`, `:40`, `:102` |
| Weights stress 0.35, Body Battery 0.20, heart rate 0.15, renormalised over present signals | CONFIRMED, **with additions**: Pulse Ox 0.10, temperature 0.05, pressure 0.05 are also in the sum. A signal counts only if its newest reading is ≤30 min old (Pulse Ox ≤12 h) | `FocusScore.mc:19-24`, `:39`, `:113` |
| Window opens after 2 ticks (10 min) at or above the user's own 70th percentile | CONFIRMED. Percentile of the last 24 h of scores, clamped to 55–90, and 65 until 12 readings exist | `FocusScore.mc:36`, `:152-155`, `:170-192`, `:33-35` |
| Live session score uses RMSSD, heart rate and accelerometer stillness against the first 3 minutes | **PARTLY.** RMSSD and heart rate are compared with the first 3 min (10 s in stage mode). Stillness is an absolute inverted-U, not compared with a baseline. The live score is anchored to the pre-session readiness score and moves ±15 × the weighted z | `FocusSession.mc:111`, `:302-303`, `:317-330` |

## A3. Heart rate unlock

| Value | Stage build (`./build-stage.sh`, demo mode on) | Normal build | Evidence |
|---|---|---|---|
| Target heart rate | max(resting + 20, 90) bpm | max(resting + 35, 100) bpm | `app/source/UnlockFlow.mc:36-37` |
| Safety cap (both) | ≤ 60 % of (220 − age); resting defaults to 60, age to 35 if the profile is empty | same | `UnlockFlow.mc:27-34` |
| Hold time | 15 s | 45 s, +15 s per repeat unlock that day | `UnlockFlow.mc:16-17`, `:48` |
| Breathing alternative | 15 s | 60 s | `UnlockFlow.mc:68`, `:104` |
| No-HR fallback offered after | 10 s without a reading | same | `UnlockFlow.mc:67` |
| Unlock length on the phone | 5 min | 5 min | `UnlockFlow.mc:18`, `:55`; `ios/Lite/LiteDetox.swift:88` |

All CONFIRMED.

## A4. Stage timeline (demo mode)

| Event | Value | Status |
|---|---|---|
| Face turns green, if the app hasn't published | Climbs 45 → 82 during its first 60 s on screen; crosses the 65 line at about **33 s** (`face/source/FocusFaceView.mc:52`) | Computed |
| Face turns green, on cue | Watch app → hold UP → **Open focus window**: score 82 + window state published at once (`app/source/StageFlow.mc:11-14`); the face shows it on its next redraw | CONFIRMED |
| Calibration in a session | 10 s (`FocusSession.mc:111`); "Calibrating to you…" cleared by 0:12 in the simulator | CONFIRMED (simulator run) |
| Focus dips | Scripted dip starts at **30 s** of session time (`FocusSession.mc:333`) | CONFIRMED (simulator run) |
| "Take 5?" nudge | About **35 s** of session time: the first-20 s average is set (`:112`), a drop of ≥15 points (`:23`, `:398`) must last 10 s (`:113`, `:405`), scored every 5 s (`:109`). **Measured in the simulator:** dip visible at 0:31 (score 86 → 68, amber), "Take 5?" on screen 37 s after launch (~35 s session time). `STAGE-SETUP.md` says ~45–55 s, which is too late | CONFIRMED (simulator run) |

## A5. Prompts

| Statement | Verdict | Evidence |
|---|---|---|
| At most one background prompt every 90 min | CONFIRMED | `app/source/FocusService.mc:12`, `:31` |
| None during sleep hours | CONFIRMED (the user's configured bedtime and wake time from the profile) | `FocusService.mc:32`, `:41-44` |
| None during a running session | CONFIRMED | `FocusService.mc:28` |
| Also | Only when the window is open, prompts are turned on, and "snooze today" isn't set; checked every 5 min | `FocusService.mc:26-29`; `app/source/FocusApp.mc:33` |

## A6. Recording

CONFIRMED. Each session is an `ActivityRecording` session, `SPORT_GENERIC` (`FocusSession.mc:157-160`), with FIT fields `focus_score` (per record, `:162-163`) and `avg_focus` (per session, `:164-165`). It is saved only if the session lasted ≥60 s (`:194-196`); shorter or "Discard" sessions are discarded.

## A7. iPhone on stage: **FocusBarLite** (answered by the team)

| Feature | Real or simulated in FocusBarLite |
|---|---|
| Watch messages (session_start / session_end / unlock_request / unlock_granted / schedule) | **Real**, Connect IQ iOS SDK 1.8.0 through Garmin Connect |
| HR unlock challenge | **Real** on the watch; the phone sends the request and receives the grant |
| App blocking | **Simulated** inside the app: the Phone tab locks pretend apps (Feed, Shorts, Chat, Games). Real Screen Time blocking is only in FocusBarCompanion (paid Apple account) |
| Calendar (#focus events → watch) | **Real** (EventKit) |
| Focus map | **Mock** cells; your own shared spots are real but stay on the phone |
| Friends | **Mock** friends; your own minutes, sessions and challenges are real |

## A8. Watch on stage: **fēnix 7 Pro** (answered by the team)

CONFIRMED: `app/manifest.xml:5` and `face/manifest.xml:5` list only `fenix7pro`, and `build-stage.sh` builds for `fenix7pro` by default.

## A9. One sentence each for a judge

- **What does the green face mean?** Your own body signals have been better than your usual for at least 10 minutes, so right now focusing should come easily: a good moment to start a session.
- **What happens if I cannot raise my heart rate?** Press START for a short breathing exercise instead, which unlocks the app the same way; the target is also capped at 60 % of your maximum heart rate, so it never asks for hard effort.

## Stage-mode caveat (found while capturing)

Demo mode is a saved setting. `build-stage.sh` only changes its **default**. If FocusBar was ever installed on the
watch with demo off, the saved "off" wins, and the stage build behaves like the normal build: 45 s hold, ≥100 bpm
target, no scripted dip, no "Take 5?" at 35 s. This happened in the simulator. **Before the pitch:** open FocusBar on
the watch → hold UP → make sure **Demo mode** is ticked. "Open focus window" appears in that menu only when demo is on,
so it doubles as the check.
