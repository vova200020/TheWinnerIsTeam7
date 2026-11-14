# Monkey C: Exceptions and Pitfalls to Avoid

A checklist for the GarminHackathon habit app. Section 1 is for the team's own list of exceptions. Section 2 onward covers common Connect IQ / Monkey C issues.

---

## 1. Team-specific exceptions

> _Add the exceptions from the team here._

- [ ] …

---

## 2. Most runtime errors can't be caught

**Most Connect IQ crashes are fatal and bypass `try/catch`.** These end the app with the IQ! crash icon:

| Error | Typical cause |
|---|---|
| `Unhandled Exception` / **Null Reference** | Calling a method or doing arithmetic on `null` |
| **Unexpected Type Error** | Mixing types (e.g. `String + Number` in the wrong order, `null` in math) |
| **Symbol Not Found** | Using an API or field the device or its API level doesn't have |
| **Out Of Memory** | Exceeding the app type's memory limit |
| **Watchdog Tripped** | Running too long in one call (e.g. a big loop in `onUpdate`) |
| **Array Out Of Bounds** | Index ≥ `size()` or negative |
| **Integer Division by Zero** | `x / 0` with Number types |

Only subclasses of `Lang.Exception` (e.g. `StorageFullException`, `InvalidValueException`, `SerializationException`) can be caught. **Prevent everything else with guard code.**

---

## 3. Null safety (the #1 crash source)

- [ ] **Null-check every field from `ActivityMonitor.getInfo()`, `Activity.getActivityInfo()`, and `Sensor.getInfo()`.** `steps`, `stepGoal`, `activeMinutesDay`, `heartRate`, `floorsClimbed` and others can be `null`, especially right after boot, during sync, or on devices without that sensor.
  ```monkeyc
  var info = ActivityMonitor.getInfo();
  var steps = (info.steps != null) ? info.steps : 0;
  ```
- [ ] **`Application.Storage.getValue()` and `Properties.getValue()` return `null`** for missing keys, including on first launch and after updates. Always provide a default.
- [ ] **`ActivityMonitor.getHistory()` covers only about 7 days,** and entries or their fields can be `null`. Don't rely on it for streak history; keep your own log in Storage.
- [ ] **`makeWebRequest` callbacks can receive `null` data** when the response code isn't 200.

---

## 4. Types and math

- [ ] **Integer division truncates.** `steps / stepGoal` gives `0` until the goal is hit. Use `steps.toFloat() / stepGoal`.
- [ ] **Guard against division by zero.** A goal can be `0` or `null` on new devices or for a goal the user hasn't set.
- [ ] **`Number` is 32-bit signed.** Use `Long` (the `l` suffix) for millisecond timestamps or large sums.
- [ ] **Settings values can arrive as the wrong type.** Some devices and phone apps send numeric settings as `String`. Coerce with `.toNumber()` and handle a `null` result.
- [ ] **Turn on type checking** (`-l 2` or `-l 3`, Strict) to catch many of these at compile time.

---

## 5. Device and API compatibility

- [ ] **Use `has` checks before newer APIs or fields** to avoid Symbol Not Found:
  ```monkeyc
  if (ActivityMonitor.Info has :activeMinutesWeek) { ... }
  if (Toybox has :Complications) { ... }
  ```
- [ ] **Set `minApiLevel` and the product list in `manifest.xml` deliberately.** Test on the smallest-memory device you support.
- [ ] **Screen shapes and sizes vary** (round, semi-round, rectangle; 176–454 px). Lay out relative to `dc.getWidth()` and `dc.getHeight()`, and use per-device resource folders where needed.
- [ ] **On AMOLED, follow the always-on rules.** In low-power or AOD mode, keep lit pixels to about 10% or less and shift content periodically. Check `System.getDeviceSettings().requiresBurnInProtection`.
- [ ] **Test on a real device.** The simulator differs in timing, memory, and sensor data.

---

## 6. Memory

- [ ] **Watch faces, glances, and background processes have small memory limits.** Some older devices allow only about 28–32 KB for background code. Check with `System.getSystemStats().freeMemory` and the simulator's Memory Viewer.
- [ ] **Load resources once** (fonts, bitmaps, strings) in `initialize()` or `onLayout()`, never in `onUpdate()`.
- [ ] **Avoid large Dictionaries and Arrays.** Every entry has object overhead. Prefer flat arrays of Numbers.
- [ ] **Monkey C uses reference counting, not a tracing GC, so circular references leak.** Use `WeakReference` for back-pointers (child → parent, view ↔ delegate).
- [ ] **Avoid building strings in loops.** Every `+` allocates.

---

## 7. Watch face rules

- [ ] **`onUpdate()` runs only once a minute in low power.** Don't expect per-second updates.
- [ ] **`onPartialUpdate()` has a strict power budget** (about 30 ms averaged per minute). If you exceed it, `onPowerBudgetExceeded()` fires and partial updates are disabled. Use a clip region and draw only the minimum.
- [ ] **Watch faces can't** use Timers, take input, vibrate or play tones (`Attention`), or call `makeWebRequest` directly. Use a background service for network calls.
- [ ] **Keep the face light on battery.** Users notice drain and leave bad reviews over it.

---

## 8. Background services

- [ ] **Temporal events run at most every 5 minutes.**
- [ ] **Annotate background code with `(:background)`.** Anything without it isn't loaded in the background process and causes Symbol Not Found.
- [ ] **No UI in the background.** Hand data back with `Background.exit(data)`. The payload is size-limited (about 8 KB) and must be a serializable type.
- [ ] **Handle `onBackgroundData()` arriving while the app isn't in the foreground.** Store the data, then render it later.

---

## 9. Storage and settings

- [ ] **Store only serializable types:** Number, Float, Long, Double, String, Boolean, Array, Dictionary, null. Storing custom class instances throws.
- [ ] **Storage is size-limited** (about 8 KB per value and about 128 KB total, depending on the device). Catch `StorageFullException`.
- [ ] **Keep a schema version key.** Storage survives app updates, so migrate old shapes explicitly.
- [ ] **Declare every setting in `properties.xml` and `settings.xml`.** Reading an undeclared property throws.
- [ ] **Reload settings in `onSettingsChanged()`.** Otherwise the app keeps using stale values until restart.

---

## 10. Networking (`Communications.makeWebRequest`)

- [ ] **It requires a phone connection.** Handle negative response codes, for example:
  - `-104` BLE connection unavailable
  - `-300` network request timed out
  - `-400` invalid response body
  - `-402` response too large
  - `-403` out of memory processing the response
- [ ] **Keep responses small.** Large JSON quickly causes `-402` or `-403`. Filter on the server side.
- [ ] **HTTPS only,** with a valid certificate chain.

---

## 11. Habit-app specific: dates and streaks

- [ ] **Compute "day keys" from local time** with `Gregorian.info(Time.now(), Time.FORMAT_SHORT)`, for example `year*10000 + month*100 + day`. Don't divide epoch seconds by 86400, because that gives UTC days.
- [ ] **Handle DST and time-zone travel.** A day can be 23 or 25 hours, and travel can skip or repeat a day. Don't break a streak because of a zone change.
- [ ] **ActivityMonitor counters reset at local midnight.** Snapshot yesterday's totals before or after rollover. Don't rely on `getInfo()` the next morning.
- [ ] **The app may not run on a given day.** Your streak logic needs to backfill missed days from history or Storage instead of assuming a daily tick.
- [ ] **Sync with Garmin Connect can change totals after the fact.** Treat "goal met" as final once the day has closed.

---

## 12. Debugging and shipping

- [ ] **Check field crash logs** in `/GARMIN/APPS/LOGS/CIQ_LOG.YML` on the device, and in the ERA (Error Reporting App) viewer in VS Code for store users.
- [ ] **Use `System.println()` while debugging, and remove it from hot paths** before release.
- [ ] **Run the Monkey C profiler** in the simulator to find Watchdog risks.
- [ ] **Before each submission, build for every device in the manifest** and smoke-test the lowest-memory one.
