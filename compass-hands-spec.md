# Compass Hands: Build Spec (fēnix 7 Pro)

> A clock you can only read by facing the right way. The dial is fixed to the world (12 = true north), so you turn your body, not the watch, to tell the time.

---

## 0. Target and constraints

| Item | Value |
|---|---|
| App type | **Device app** (`watch-app`). Not a watch face, because faces refresh only once a minute in low power and can't run a 10 Hz timer |
| Primary device | fēnix 7 Pro: **260×260 round MIP**, 64 colors, touchscreen + 5 buttons |
| Also build for | fēnix 7S Pro (240×240), fēnix 7X Pro (280×280). Layout must scale from `dc.getWidth()` |
| Manifest product IDs | `fenix7pro`, `fenix7pronowifi`, `fenix7spro`, `fenix7xpro`, `fenix7xpronowifi` *(confirm in SDK Manager)* |
| Min API level | 4.2+ (the fēnix 7 Pro runs a CIQ 5.x System) |
| Permissions | `Sensor`, `Positioning` (Sun mode only) |
| Refresh | 10 Hz while visible; stop the timer in `onHide()` |

---

## 1. Feature scope

### MVP (build first)
1. **World-locked dial.** The dial rotates by `-heading`, so 12 always points to true north.
2. **Normal hands** drawn at clock angles relative to the dial.
3. **"Aligned" feedback.** When heading is within ±10° of north: the dial turns bright, a short vibration plays, and the digital time flashes in the centre.
4. **Heading smoothing** with wraparound handled correctly.
5. **Calibration / "no heading" state.** If heading is null or unreliable, show "Wave in a figure-8" and fall back to a static dial.

### Modes (cycle with the UP/DOWN buttons)
| # | Mode | Rule |
|---|---|---|
| 1 | **North Clock** | 12 = north. Reads correctly only when you face north. |
| 2 | **Split Bearings** | The hour hand is visible only facing **N** (±15°) and the minute hand only facing **E** (±15°). |
| 3 | **Treasure Hunt** | Hands are hidden. Proximity to the target bearing drives brightness and vibration pulses ("warmer/colder"). |
| 4 | **Sun Mode** | 12 points at the sun's real azimuth (from GPS + time). At night, it points at the sun's position below the horizon and shows a "☾" marker. |

### Stretch (only if time allows)
- **Drift.** With no steps for 60 min, north drifts +3°/min. Walking 20 steps resets it.
- **Daily ritual counter** (Storage): "faced north 14 days in a row". This ties to the habit research and uses a forgiving weekly streak.

---

## 2. Project structure

```
CompassHands/
├── manifest.xml
├── monkey.jungle
├── resources/
│   ├── drawables/          launcher_icon.png (40×40 for fēnix 7 Pro)
│   ├── strings/strings.xml
│   ├── properties.xml      default mode, tolerance, vibration on/off
│   └── settings.xml        user-facing settings in Connect IQ app
└── source/
    ├── CompassHandsApp.mc      AppBase: lifecycle, settings load
    ├── CompassView.mc          WatchUi.View: timer, drawing
    ├── CompassDelegate.mc      BehaviorDelegate: buttons + touch
    ├── HeadingSource.mc        sensor read + smoothing + status
    ├── ClockMath.mc            angles, bearings, alignment checks
    ├── SunCalc.mc              solar azimuth (Sun mode)
    ├── Modes.mc                enum + per-mode rules
    └── Haptics.mc              vibration patterns, rate-limited
```

---

## 3. Module specs

### 3.1 `CompassHandsApp.mc`
- `onStart()`: load properties (mode, tolerance, haptics).
- `getInitialView()`: returns `[new CompassView(), new CompassDelegate(view)]`.
- `onSettingsChanged()`: reload properties, then `WatchUi.requestUpdate()`.

### 3.2 `HeadingSource.mc`
**Responsibility:** produce a smooth, trustworthy heading in radians, or null.

```text
state: sx, sy (smoothed sin/cos), heading, lastRaw, status ∈ {OK, NO_DATA, UNSTABLE}

update():
    raw = Sensor.getInfo().heading                // radians, true north; may be null
    if raw == null → status = NO_DATA; return
    sx = α·sx + (1-α)·sin(raw)                     // α = 0.80 (tune 0.7–0.9)
    sy = α·sy + (1-α)·cos(raw)
    heading = atan2(sx, sy)                        // wrap-safe average
    magnitude = sqrt(sx² + sy²)
    status = magnitude < 0.6 ? UNSTABLE : OK       // vectors disagree → jittery
```
- If `Sensor.getInfo().heading` is null on the device, fall back to `Activity.getActivityInfo().currentHeading`.
- **Note:** heading is most reliable with the watch held level. Show a small "hold flat" hint while status is `UNSTABLE`.

### 3.3 `ClockMath.mc`
```text
TWO_PI = 2π
norm(a)            → a mod 2π into [0, 2π)
angDiff(a, b)      → signed smallest difference in (-π, π]
hourAngle(h, m)    → ((h % 12) + m/60) · π/6        // clockwise from 12
minuteAngle(m, s)  → (m + s/60) · π/30
dialRotation(hdg)  → -hdg                           // rotates world-locked dial
isFacing(hdg, target, tolDeg) → |angDiff(hdg, target)| ≤ tolDeg·π/180
screenPoint(cx, cy, r, angle) → (cx + r·sin(angle), cy - r·cos(angle))
```
On screen, a hand's final angle is `dialRotation + handAngle`.

### 3.4 `SunCalc.mc` (Sun mode only)
- Inputs: lat, lon (degrees), UTC time.
- Output: solar azimuth (radians, clockwise from north) and elevation.
- Use the **NOAA simplified solar position** algorithm (about 25 lines): day of year → declination + equation of time → hour angle → azimuth via `atan2`.
- Location: `Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPos))` on entering Sun mode. Cache it in Storage and reuse it if no fix arrives within 30 s.
- Recompute the azimuth once a minute, not every frame.

### 3.5 `CompassView.mc`
**Lifecycle**
- `onShow()`: start `Timer` at 100 ms → `heading.update(); WatchUi.requestUpdate()`.
- `onHide()`: stop the timer (saves battery).
- `onLayout()`: cache `cx, cy, r = min(w,h)/2`, fonts, and colors once.

**Draw order in `onUpdate(dc)`**
1. Clear to black.
2. **Dial ring:** 12 tick marks rotated by `dialRotation`. Draw the 12 marker in red, larger, with an "N" in North Clock mode.
3. **Cardinal ghost letters** (N/E/S/W), dim, rotated with the dial (helps orientation).
4. **Hands** according to mode rules (see 3.7). Hour: thick, 0.5r. Minute: thin, 0.8r.
5. **Fixed "you" indicator** at the top of the screen (a small triangle). It never rotates and shows which way you're facing.
6. **Alignment state:** if aligned, show the digital time in the centre plus a brightness boost (white versus gray on MIP).
7. **Status line** (bottom): the mode name, or a "Calibrate / Hold flat" hint.

**MIP color guidance:** use high-contrast pure colors (`COLOR_WHITE`, `COLOR_RED`, `COLOR_DK_GRAY`) because MIP has 64 colors and gradients band. Use `dc.setAntiAlias(true)` where supported.

### 3.6 `CompassDelegate.mc` (fēnix 7 Pro buttons)
| Button | Callback | Action |
|---|---|---|
| UP | `onPreviousPage()` | previous mode |
| DOWN | `onNextPage()` | next mode |
| START | `onSelect()` | toggle "reveal" (show the digital time for 3 s; this is the cheat button) |
| BACK | `onBack()` | exit app (return false) |
| Hold UP | `onMenu()` | menu: tolerance (5/10/20°), haptics on/off, calibrate tips |
| Touch tap | `onTap()` | same as START |

### 3.7 `Modes.mc`: per-mode rules
```text
NORTH_CLOCK:
    target = 0 (north)
    draw both hands always
    aligned = isFacing(heading, 0, tol)

SPLIT_BEARINGS:
    showHour   = isFacing(heading, 0,     15°)
    showMinute = isFacing(heading, π/2,   15°)
    draw only visible hands; ghost outline for hidden ones

TREASURE_HUNT:
    target = 0
    d = |angDiff(heading, target)|            // 0..π
    brightness = 1 - d/π                       // map to 4 gray levels on MIP
    haptic pulse interval = lerp(200ms, 1500ms, d/π)
    hands visible only when d ≤ tol

SUN_MODE:
    target = sunAzimuth
    dial's "12" anchored to sunAzimuth instead of 0
    if elevation < 0 → draw ☾ marker, dim dial
```

### 3.8 `Haptics.mc`
- `Attention.vibrate([new Attention.VibeProfile(50, 80)])` on **entering** alignment only (edge-triggered, not every frame).
- Rate limit: at most 1 buzz per 1.5 s. Treasure Hunt uses its own pulse scheduler.
- Check `Attention has :vibrate` and the user setting.

---

## 4. Settings (`properties.xml` / `settings.xml`)
| Key | Type | Default |
|---|---|---|
| `defaultMode` | number (0–3) | 0 |
| `toleranceDeg` | number | 10 |
| `hapticsOn` | boolean | true |
| `showCardinals` | boolean | true |

Coerce every value on read (`.toNumber()`, null → default). See `monkey-c-pitfalls.md` §4 and §9.

---

## 5. Storage
| Key | Purpose |
|---|---|
| `schemaVersion` | migration guard (start at 1) |
| `lastLat`, `lastLon` | cached position for Sun mode |
| `northDays` | array of day keys (yyyymmdd, local) when the user aligned north (stretch) |

---

## 6. Build milestones (hackathon order)

| # | Milestone | Done when |
|---|---|---|
| 1 | Skeleton app runs on the fēnix 7 Pro simulator | Black screen, BACK exits |
| 2 | Static analog clock (no compass) | Hands correct vs. device time |
| 3 | `HeadingSource` + world-locked dial | Rotating sim heading rotates the dial smoothly, with no jump at 359°→0° |
| 4 | Alignment feedback (visual + haptic) | Buzz once when entering ±10° of N |
| 5 | Mode switching + Split Bearings | UP/DOWN cycles; hands appear only at N/E |
| 6 | Treasure Hunt | Warmer/colder pulses feel right on a real watch |
| 7 | Sun mode | Azimuth matches a reference (e.g. suncalc.org) within ±2° |
| 8 | Real-device test + polish | Tested outdoors, away from metal; calibration hint works |
| 9 | Stretch: Drift + north streak | — |

---

## 7. Testing checklist
- [ ] Simulator: **Simulation → Set Heading / Sensor data** to sweep 0–360° and confirm there's no jump at the wrap.
- [ ] Null heading at app start: the "Calibrate" state shows and nothing crashes.
- [ ] 7S Pro (240) and 7X Pro (280) layouts: nothing clipped.
- [ ] 10 minutes open: no memory growth (Memory Viewer), and `onHide` stops the timer.
- [ ] Sun mode checked at a known location and time against a reference site.
- [ ] Real watch: indoors near a laptop, the heading will be wrong. Demo outdoors or away from metal.
- [ ] Haptics don't fire continuously while you stand aligned.

---

## 8. Demo script (for judges)
1. "What time is it?" Hand the judge the watch; the dial reads sideways.
2. "Face north." They turn, the watch buzzes, and the time snaps into place.
3. Switch to **Split Bearings**: they quarter-turn to get the minutes.
4. Finish with **Sun Mode**: "12 o'clock is wherever the sun actually is."
5. Pitch: *time becomes something you do with your body, which helps brains that tune out passive information. And it gets people to stand up and move.*
