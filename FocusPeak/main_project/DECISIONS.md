# DECISIONS: FocusPeak

> One dated line per decision. The plan with the reasons and the sources is `PLAN_v2.html`.

## 0. Problem statement (organizers, 2026-11-14)

"Build something that would make your own Health & Wellness better." Pick something you struggle
with (sleep, staying active, focus or recovery) and build an app on Garmin that helps with it. Bonus
points for every Garmin sensor that the app puts to real use.

## 1. Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-11-14 | Idea: FocusPeak. Score each focus session, earn each phone break with heart rate, learn the best time and place of the user | Focus is on the organizers' list. The heart rate gate is the creative hook |
| 2026-11-14 | App type: device app (`watch-app`) for `fenix7pro` and `fr265`, software development kit (SDK) 9.1.0 | A watch face has no sensors, no vibration and no buttons |
| 2026-11-14 | Build order: watch app first, then the phone prototype, then watch face and community | The watch app must work alone and its screens must be excellent |
| 2026-11-14 | Session timing: 24 min focus + 6 min break at the start. Break = block / 4, between 5 and 15 min. Block grows by 5 min after 3 scores of 70 or more, shrinks after 2 scores below 50, range 15 to 90 min | Biwer 2023 (PubMed 36859717), Albulescu 2022 (doi 10.1371/journal.pone.0272460). 90 min is a design cap |
| 2026-11-14 | Break gate: heart rate at or above max(100, resting + 30) bpm for 10 s | Acute exercise helps attention (PubMed 39883421). Reachable in 30 to 60 s |
| 2026-11-14 | Focus Score = time on task 50, wrist stillness 30, calm heart rate 20. It is a proxy, and the pitch says so | The watch cannot measure focus directly |
| 2026-11-14 | Readiness = weighted mean of the inputs that are present (Body Battery 25, calm 20, sleep 15, hour 15, place 10, do-not-disturb 10, temperature 5) | A missing input must not pull the score down |
| 2026-11-14 | A block that the user ends early gets a score but no streak day. A skipped gate resets the streak | The streak rewards the habit, not the start |
| 2026-11-14 | No manual data entry for sleep | Users do not like data entry |
| 2026-11-14 | Cloud data (sleep score) is shown only as marked example data in demo mode | No real access today. The judges are Garmin staff |
| 2026-11-14 | Barometer and Pulse Ox are not focus signals. Radar and nRF boards are out | No source supports the claim. No time |
| 2026-11-14 | In demo mode the store holds example data and writes nothing | The real log of the user stays clean, and the example is marked DEMO on each screen |
| 2026-11-14 | One floor of stairs (3 m on the barometer) also opens the break gate | A real use of the barometer. Stairs are a good short workout |
| 2026-11-14 | The glance is moved to a later version | It cannot be checked in the simulator without screen control, and a glance error can stop the app start |
| 2026-11-14 | The watch sends a state only when it changes and at a slow period (focus 60 s, earn 2 s, break 30 s). Only the newest state is kept. The phone counts down by itself | A message each second fills the Bluetooth queue |
| 2026-11-14 | "Phone link" is a menu switch, off by default | The watch app must work alone, and the simulator shows an error dialog for each message with no phone attached |
| 2026-11-14 | Community runs on a local backend for the demo. It gets a place label only, never coordinates, and a session at Home is never shown to others | The user asked for community features, and privacy is a selling point |
| 2026-11-14 | The backend listens on 127.0.0.1 only. `--lan` opens it to the Wi-Fi | Safe default on a public network |
| 2026-11-14 | The app redraws only when the screen content can change, and never while a menu covers it | A redraw request each second made the menu freeze on the real watch |
| 2026-11-14 | The phone lock is a full-screen page with a 3 s hold for emergencies | A web page cannot block other apps. The hold makes an unlock a decision, not a reflex |
| 2026-11-14 | The watch face is a separate app that reads Body Battery and stress itself | A watch face cannot read the storage of the watch app |
| 2026-11-14 | Shared terms: Ready, Focus, Move to unlock, Break, Focus score, Streak, Block. Each has one word, one color and one pill-shaped box on the watch (`watch/source/core/Terms.mc`) and on the phone (`focuspeak-phone/src/terms.js`). Sentence case, condensed font | The user must recognize a concept on both devices and never guess. The phone said "Locked" and "Unlocked" where the watch said "Focus" and "Break" |
| 2026-11-14 | Watch colors use the hex values of the phone theme | One color per term on both devices. A 64-color display shows the nearest color |
| 2026-11-14 | Touch on the watch is mapped by hand: tap = START, swipe up and down = pages, swipe right = BACK | Gestures felt slow and wrong on the Forerunner 265 with the default mapping |
| 2026-11-14 | Focus time means no phone time: leaving the phone app during Focus or Move to unlock is counted and lowers the Focus score on the watch | The owner accepted that a full lock is not always possible, so the app measures and charges phone use instead |
| 2026-11-14 | The break shows the live heart rate, "Recovered" within 20 bpm of rest, and the steps since the break began | The break is for recovery. A heart rate near rest is the signal to start the next block |
| 2026-11-14 | Sleep from the phone counts only for the day it arrived. 4 h or less gives 0 readiness points for sleep, 8 h or more gives 100 | Old sleep data must not look current |
| 2026-11-14 | Phone link: Connect IQ Mobile SDK for iOS, no server. First a phone prototype in one HTML file | Privacy message: data stays on the wrist and the phone |

## 2. Versions

| Tag | Content | Tested |
|---|---|---|
| `v1` | Focus loop: Ready, Focus, Earn, Break, Summary. Demo mode in the menu. 8 unit tests | Simulator (`fenix7pro`): tests 8 of 8, screens checked. Not tested on a watch |
| `v2` | Personal baseline (best time, best place, own block length), places by GPS with a label list, temperature and Pulse Ox inputs, stairs open the gate (barometer), block saved as an activity for Garmin Connect, Ready screen with 3 pages | Simulator (`fenix7pro`): tests 12 of 12, app starts with no error. New screens not seen. Not tested on a watch |
| `v3` | Watch side of the phone link: sends ready, focus, earn, break and summary messages, receives the sleep hours and uses them in the readiness score. Handoff note `phone/LINK.md` | Simulator (`fenix7pro`): tests 15 of 15, app starts with no error. Link not tested with a phone. Not tested on a watch |
| `v4` | Local backend (`backend/server.py`): relay from the watch to the phone page, friends leaderboard, shared places, friends feed. Watch menu switch "Server link" for the simulator. Phone page has a live mode and a Friends tab | Backend: 9 of 9 tests. Phone page with the backend: checked in the browser with posted test messages. Watch simulator to backend: not checked |
| `v5` | Phone page redesign (full-screen lock with a 3 s emergency hold, journal with a week chart, friends with a team challenge and kudos, sources card). Backend: journal of the user, week, challenge, kudos, data saved in `data.json`. Watch: Settings page, redraw only on change, Pulse Ox only on the Inputs page. Watch face as a separate app in `watchface/` | Watch tests 15 of 15, watch face tests 6 of 6, backend tests 14 of 14. Phone page checked in the browser with posted messages. Watch face not seen on a screen. Watch to backend not confirmed |
| `v6` | Live heart rate recovery and steps in the break, real phone lock by Android app pinning (`backend --pin`), every block recorded | Watch tests 16 of 16, backend 18 of 18. Pinning confirmed through the lock state of Android |
| `v7` | Phone use during focus lowers the Focus score (5 points per exit, 1 point per 6 s, 30 at most). Demo streak fix. `HANDOVER.md` | Watch tests 17 of 17, backend 20 of 20, phone logic 14 groups. Leave detection confirmed on the phone. The lower score on a real watch screen is not yet seen |
