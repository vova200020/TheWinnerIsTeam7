# Stage setup: real watch + iPhone, free Apple ID

Do this **the day before** the demo. Free-account iPhone installs expire after 7 days.

## 1. Watch (no account needed)

```sh
cd FocusBar
./build-stage.sh              # or ./build-stage.sh <device-id> if your watch isn't a fēnix 7 Pro
```

1. Connect the watch over USB. On a Mac, Garmin watches show up as MTP devices, so use **OpenMTP** (free) to see their files.
2. Copy `stage/FocusBar.prg` and `stage/FocusFace.prg` into `GARMIN/APPS/`.
3. Unplug the watch. Then:
   - Choose **FocusBar Face** as your watch face.
   - Add the **FocusBar** glance to your glance list.

Tapping the FocusBar face opens a **quick start** screen: START starts a session with your last tag and length, UP changes the tag, and DOWN changes the length.

Both stage copies have **demo mode on by default**:
- The face climbs to green within its first minute on screen.
- The app's hold UP menu has **Open focus window**.
- Sessions follow the stage timeline.

## 2. iPhone: FocusBar Lite (free Apple ID)

1. **Xcode → Settings → Accounts → +**, then sign in with your Apple ID. This creates a free "Personal Team".
2. Open the project:
   ```sh
   cd FocusBar/ios && xcodegen generate && open FocusBarCompanion.xcodeproj
   ```
3. Select the **FocusBarLite** target → **Signing & Capabilities**:
   - Team: *(your name) Personal Team*
   - Bundle Identifier: make it unique, e.g. `com.yourname.focusbar`
4. Plug in the iPhone. Turn on **Settings → Privacy & Security → Developer Mode**, then restart when asked.
5. Choose the **FocusBarLite** scheme and your iPhone, then press **Run**.
6. On the iPhone, go to **Settings → General → VPN & Device Management**, tap your Apple ID, then tap **Trust**.
7. Install **Garmin Connect** and pair the watch, if they aren't already.
8. In FocusBar: **Today → Choose watch in Garmin Connect**. Pick your watch; Garmin Connect bounces you back to FocusBar. The status should read **Connected** and **FocusBar installed**.

Allow notifications when asked.

## 3. Rehearse the 3-minute run (spec timings in stage mode)

| Time | Watch | Phone |
|---|---|---|
| before | Face on screen ≥ 1 min, so it's **green** | FocusBar open on the **Phone** tab |
| 0:35 | **Tap the green face** → quick start ("Coding · 25 min · DEEP") → **START**. *(Alternative with the buzz: open FocusBar → hold UP → Open focus window → START.)* | "Deep focus started": Feed/Shorts/Chat lock |
| 0:50 | | Tap **Feed** → shield → **Unlock with watch** |
| 1:00 | Unlock challenge opens: **hand to a judge**. Target ≈ resting + 20 bpm, hold 15 s | Shield shows "Check your watch" |
| ~1:30 | "Unlocked" | Shield closes, Feed shows a "4:59 left" countdown |
| 1:35 | Back to the session → focus dips → **Take 5?** → End | |
| 1:50 | Rate 4 → XP, award, 1/5 this week | "Session saved. Apps are unblocked." |

**Checks during rehearsal:**
- **Session doesn't reach the phone:** open FocusBar on the phone first (iOS only delivers watch messages to it reliably while it's running), then start the session again.
- **Unlock request doesn't reach the watch:** the FocusBar app must be **open on the watch**. If it isn't, the phone asks the watch to open it and retries 3 times.
- **Judge can't reach the target:** press **START** for the 15-second breathing alternative. Pitch it as the accessibility and safety feature it is.
- **Backup:** record a full run on video. As a last resort, use **Today → Demo without a watch**.

**Before going on stage:** clear any earlier rehearsal session (hold UP → End, or **Stop blocking now** on the phone), and check both devices are charged.
