# FocusBar pitch assets: report

On stage: **fēnix 7 Pro** (`fenix7pro`) + **FocusBarLite** on the iPhone (answers from the team).

## 1. Deliverables

| File | Made | Size | How |
|---|---|---|---|
| `facts.md` | yes | 9 KB | Read from the code with file:line, plus timings measured in the simulator |
| `w1_face_green.png` / `@4x` | yes | 30 / 55 KB | Connect IQ simulator, **real stage `FocusFace.prg`**, after the app published "window open, 82" |
| `w2_quickstart.png` / `@4x` | yes | 35 / 62 KB | Simulator, stage app code; a scratch copy opens the quick-start screen directly (see note A) |
| `w3_session.png` / `@4x` | yes | 33 / 60 KB | Simulator, real session running (scratch copy starts it); simulator heart rate 162 bpm, HRV 83 |
| `w4_unlock.png` / `@4x` | yes | 32 / 61 KB | Simulator, real unlock challenge, 8 of 15 s held, simulator heart rate 162 bpm |
| `w5_take5.png` / `@4x` | yes | 24 / 47 KB | Simulator: the nudge fired **by itself** from the real stage timeline, ~35 s into the session |
| `w6_summary.png` / `@4x` | yes | 37 / 65 KB | Simulator, real summary screen with **sample** session data (25:23, avg 74) |
| `p1_today.png` | yes | 321 KB | iOS Simulator (iPhone 17 Pro, iOS 26.2), FocusBarLite, `-demoHistory 1`: **new 40 h weekly-goal ring** |
| `p2_locked.png` | yes | 189 KB | iOS Simulator, `-tab detox -demoStart deep` |
| `p3_shield.png` | yes | 122 KB | iOS Simulator, tap on Feed (scratch UI test, see note B) |
| `p4_check_watch.png` | yes | 111 KB | iOS Simulator, tap on "Unlock with watch" |
| `p5_unlocked.png` | **no** | – | Needs a real `unlock_granted` from the watch. Take it on the iPhone during rehearsal |
| `p6_map.png` | yes | 1.1 MB | iOS Simulator, `-tab map`, simulator location set to Calgary, mock cells |
| `p7_friends.png` | yes | 304 KB | iOS Simulator, `-tab friends`, mock friends |
| `watch_face_green.png` | yes | 126 KB | `make_composites.py` (Pillow): 1100×1100, #263140 12 px bezel, transparent outside |
| `demo_strip.png` | yes | 568 KB | `make_composites.py`: 3520×640, w1 · p2 · w4 · w5 · w6, transparent |
| `make_composites.py` | yes | 3 KB | Rebuilds the two composites (`pip install pillow`) |
| `video_shotlist.md` | yes | 2 KB | 8 steps, ~55 s, from STAGE-SETUP.md section 3 with the measured timings |
| `demo_fallback.mp4` | **no** | – | To be recorded by the team (see the chat instructions) |
| `video_check.txt` | **no** | – | Made after the video exists |

Notes:
- **A. Watch captures.** The simulator's buttons can't be pressed from a script, so a throwaway copy of the stage app (in a scratch folder, not in the repo) opened each screen directly. It runs the same FocusBar code and the same demo state as the stage "Open focus window" action. Everything is cropped to the round 260×260 screen on black; the `@4x` files are nearest-neighbour 1040×1040.
- **B. iPhone captures.** A throwaway UI-test project (scratch folder) launched the installed FocusBarLite with the README launch arguments and tapped through. The status bar was set to 9:41. There is no personal data: no calendar events, mock friends, and simulator location only.
- **C. "Watch connected"** can't be shown in the iOS Simulator (Garmin Connect doesn't run there), so p1 shows "NO WATCH". On the real iPhone it shows LIVE.

## 2. Signal count (say this out loud)

"FocusBar uses eight Garmin signals to score your focus: stress, Body Battery, heart rate, Pulse Ox, temperature and air pressure for readiness, plus heart-rate variability and wrist stillness during a session. GPS adds where you focused."

## 3. Not confirmed / not made / risks

1. **Unlock challenge stalls at "hold 1 s more" in the simulator.** It never showed "Unlocked" in two runs, and no crash was logged. Likely cause: the final step (send `unlock_granted` to the phone + buzz). **Test on the real watch + iPhone first.** If it stalls, use the breathing alternative (START on the challenge) for the demo. Per this task's rules the code was not changed.
2. **Demo mode must be checked on the watch.** It is a saved setting, and a saved "off" overrides the stage build's default (it happened in the simulator: hold 45 s, target 100 bpm, no dip). Watch → FocusBar → hold UP → **Demo mode** ticked; "Open focus window" in that menu confirms it's on.
3. `p5_unlocked.png`, `demo_fallback.mp4` and `video_check.txt` are not made: they need the real devices.
4. Real Screen Time shield (`p3_shield_real.png`): not applicable. FocusBarLite simulates the shield in-app.
5. Small layout issue: on `w6_summary`, "+47 XP" touches the award chip. Not changed.

## 4. Differences from the prompt's assumptions

| Prompt assumed | Actually |
|---|---|
| "8 Garmin signals in real use", including GPS and skin temperature | 8 change a score, but **GPS doesn't** (context only) and **barometric pressure does** (not in the list). "Skin temperature" is the watch's **temperature sensor** history |
| Weights stress 0.35, Body Battery 0.20, HR 0.15 | Also Pulse Ox 0.10 (only lowers), temperature 0.05, pressure 0.05 |
| Live score vs the first 3 minutes for RMSSD, HR **and** stillness | Stillness is an absolute inverted-U, not baseline-relative; the live score is anchored to the pre-session readiness score |
| STAGE-SETUP: "Take 5?" at ~45–55 s | Measured **~35 s** of session time |
| Today tab | It is called the **Focus** tab now, and (requested today) its top ring shows **this week's focus time vs a 40 h goal**; the middle tile shows sessions this week |
| A device-native screenshot function | Window capture cropped to the display at exactly 2× (519 px → 260 px) |
