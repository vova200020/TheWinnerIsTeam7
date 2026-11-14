---
name: hackathon-code-standard
description: "The code standard for this hackathon repo: Monkey C for the Connect IQ app (Fenix 7 Pro, SDK 9.1.0), C on Zephyr for the nRF52840-DK, and Python helper tools (radar or data scripts). Clean, readable code that demos reliably: functional core and thin device shell, explicit state machines, a fake data source for every piece of hardware (demo mode), the memory limits of the watch, hardware safety when wiring boards, watch UI and UX rules, and tests that run without hardware. Use whenever you write, change, review or plan code here, even a small fix, and when the user says clean code, refactor, code review, demo mode, UI, UX, glance, watch face, data field, widget, BLE, SPI, wiring or flashing."
---

# Hackathon code standard

The goal is a demo that works every time in front of the judges, and code that a teammate reads in
one pass. The judges score Execution and Deployment ("does it work, is there a live deployment we
can test") and User Experience and Design from 0 to 5 each. Reliability and a clear screen beat
extra features.

Two standards, one goal:
- **Backend** (data, sensors, Bluetooth Low Energy (BLE), SPI, storage): correct, testable without
  hardware, vendor facts checked in the datasheet or the API docs.
- **Front end** (watch screens, phone settings, slides) and **every reply**: easy to use, quiet,
  readable in one glance.

## 0. Before you write code

1. **Event rule.** The organizers allow ideas but nothing already built. App code starts at the
   event (Saturday 2026-11-14). Before that, only setup, research and throwaway checks in the
   scratchpad.
2. Read `START_HERE.md` and `MAP.md`. Read the code you will touch and grep every caller of each
   function you change.
3. Start from the smallest working sample: `<SDK>\samples\` (for example `SensorHistory`,
   `ActivityTracking`, `BackgroundTimer`, `Attention`, `Notifications`, `Menu2Sample`,
   `NordicThingy52`), the Zephyr `samples/bluetooth/`, or the EiE lessons in
   `hardware/nrf52840-dk/eie_nrf52840/doc/`. Copy it, build it for `fenix7pro`, then change it.
4. A design decision (app type, data source, BLE profile, a dropped feature) gets one line in
   `main_project/DECISIONS.md`: date, decision, reason. The pitch reuses these lines.

## 1. Where code lives (functional core, imperative shell)

| Layer | Monkey C (Connect IQ) | C (Zephyr, nRF52840) | Python | Rule |
|---|---|---|---|---|
| Core: logic | `source/core/*.mc`: pure functions and small classes (scores, thresholds, streaks, goals, state transitions) | `src/logic.c` | `core.py` | No `WatchUi`, `Graphics`, `Communications`, `BluetoothLowEnergy`, sensor, storage or timer calls |
| Shell: devices and I/O | Sensor reads, `Application.Storage`, `Communications`, `BluetoothLowEnergy`, the background service | Drivers, BLE stack, SPI, GPIO | Serial port, files, network | Thin. Talks to the device, then calls the core |
| Presentation | `View`, `Delegate`, glance, layouts, resources | LEDs, log output | Plots | Draws and routes input. No logic lives only here |
| Tests | `(:test)` functions on the core | `ztest` when time allows | `pytest` | Run without hardware |

Why: a pure function is testable in seconds with known inputs. Logic inside `onUpdate` or a BLE
callback is testable only on the watch, so in practice it is not tested.

## 2. Readability rules

1. **Units in names.** `hr_bpm`, `stress_0_100`, `t_s`, `dist_m`, `sleep_min`, `range_m`. A number
   without a unit is the most common silent bug.
2. **Named constants with a reason.** `const NUDGE_AFTER_MIN = 50; // sit time before a move nudge`.
   No unexplained literal in logic code. Vendor constants come from a datasheet or the API docs.
3. **Types on.** Monkey C: annotate parameters and returns (`as Number`) and build with type
   checking (`project.typecheck = 2` in `monkey.jungle`, or `-l 2`; levels 0 to 3). A type error at
   build time is a crash that the judges never see.
4. **Null checks at the boundary.** Sensor, history and activity values can be `null`. Check once,
   in the shell, and pass clean values to the core.
5. **Comments say why, not what.** A comment explains a choice, a hardware fact or a trap.
6. **Small functions, one job each.** A function that reads, scores and draws is three functions.
7. **Names from the domain.** Use Garmin and radar words (glance, data field, Body Battery, chirp,
   frame). Do not invent private words.
8. **Match the file.** Follow the naming, import style and comment density of the code around you.

## 3. Design patterns that fit a one-day build

| Pattern | Use it for | Example |
|---|---|---|
| Pipeline of pure functions | Samples to features to a score to one message | `toMinutes()`, `streak()`, `nudgeText()` |
| Explicit state machine | App or device life cycle: idle, scanning, connected, streaming, error. One owner per transition | Zephyr State Machine Framework (EiE lesson 6), a Monkey C `enum` plus one `switch` |
| Thin device class | One object owns one BLE device, SPI bus or sensor, and releases it | `RadarLink`, `HrSource` |
| Fake data source (demo mode) | A class with the same interface that plays recorded or synthetic data. One constant or one setting switches it on | `const DEMO_MODE = true;` |
| Settings object | User settings read once from `Application.Properties` into one object | `Settings.load()` |

Do not use these, because they add code that nobody reads and nobody demos: deep class
hierarchies, frameworks, global mutable state spread across files, an option that nobody sets.

## 4. Senior practice for a one-day build

1. **Keep `main` runnable.** Build after every change (a `monkeyc` build takes about 5 s). Commit a
   working state at least every hour once the folder is under git.
2. **Freeze the demo path.** At least 45 minutes before pitching, stop features. Only fix the path
   the pitch shows.
3. **Memory budget** (SDK 9.1.0 device file for `fenix7pro`): watch app 768 KB, data field
   256 KB, watch face 128 KB, glance 64 KB, background 64 KB. The glance and the background
   service run out first. Keep big arrays, strings and images out of them.
4. **Background timing.** A background temporal event cannot run less than 5 minutes after the
   last one (Connect IQ API docs, `Toybox.Background`). Design nudges around this limit.
5. **Permissions.** Request in `manifest.xml` only what the app uses (for example `SensorHistory`,
   `Background`, `Communications`, `BluetoothLowEnergy`). Every extra permission is one more
   question for the user.
6. **API level.** The Fenix 7 Pro runs Connect IQ 5.2.0. Check the minimum API level of every
   call in the API docs. Guard optional features with `has` (`if (Toybox has :Complications)`).
7. **Hardware is a trust boundary.** Check the length and range of every BLE packet, SPI frame
   and sensor value. Count dropped packets and show the count in the debug view.
8. **Hardware safety.** Power off before you wire. Check the input-output voltage of both sides
   in their datasheets before you connect a pin. One person wires, a second person checks. Never
   hot-plug a shield.
9. **Errors are loud.** Show a short error state on the watch ("Radar not found") and log details
   with `System.println` for the simulator console. No empty `catch`.
10. **Shortcuts are marked.** `// shortcut: <the limit>, <when to fix>`, so `grep -rn "shortcut:"`
    lists them before the pitch.

## 5. Tests

1. Every risky rule in the core gets one `(:test)` function: a threshold, a streak, a time window,
   a unit conversion, a packet parser.
2. **Test with known answers.** Seven days of step counts with a known streak must give that
   streak. A packet with a known payload must give the known values.
3. Commands (from the app folder, simulator running):

```bash
"$SDK/monkeyc.bat" -f monkey.jungle -d fenix7pro -o bin/app-test.prg -y "$KEY" -t
MSYS_NO_PATHCONV=1 "$SDK/monkeydo.bat" bin/app-test.prg fenix7pro /t
MSYS_NO_PATHCONV=1 "$SDK/monkeydo.bat" bin/app-test.prg fenix7pro /t Module.testName
```

4. Check the screens in the simulator for `fenix7pro`. Check memory with the simulator memory view
   before you add a feature to the glance or the background service.
5. **Report results as they are.** Code that ran only in the simulator is "not tested on the
   watch". Say so.

## 6. Where to look before you assume

Guessing an API limit or a pin voltage costs more time than looking it up. Put the link in a
comment when the fact drives the code.

| Fact | Where to look |
|---|---|
| A Connect IQ API, its permission and minimum API level | The API page on developer.garmin.com, or `<SDK>\doc\` |
| A device limit (memory, screen, buttons) | `%APPDATA%\Garmin\ConnectIQ\Devices\fenix7pro\compiler.json` or `simulator.json` |
| A hardware fact (pin, voltage, register) | The datasheet or user guide in `hardware/*/docs/` |
| A number shown to the user in the app | The page that published it (quick check with `ASG-audit`) |

## 7. Front end: watch UI and UX

The user glances at the wrist for about two seconds, often while moving, often outdoors. The
Fenix 7 Pro has a 260 x 260 pixel round memory-in-pixel (MIP) display with a touchscreen. Its
app keys are enter (select), up (previous page, hold for menu), down (next page) and back
(`simulator.json`).

| Topic | Rule | Why |
|---|---|---|
| One glance | One number or one message per screen, in the largest font that fits | A glance lasts about two seconds |
| Safe area | Keep text inside the centre square of about 184 x 184 pixels (260 divided by the square root of 2) | The round edge cuts the corners |
| Contrast | Light text on a black background. Saturated, high-contrast colors only. No gradients and no thin fonts | MIP screens show few colors and read best in daylight |
| State | Show the current state in words, not only in color ("On track", "Move now") | Color alone fails for color-blind users |
| Color meaning | Green = on track, amber = attention, red = off track. One meaning per color in the whole app | The user reacts without reading |
| Input | Use the native behaviors through `BehaviorDelegate` (`onSelect`, `onBack`, `onNextPage`, `onPreviousPage`, `onMenu`). Touch is a bonus, never the only way | Users already know the buttons |
| Nudges | Vibrate (`Attention.vibrate`) only when the user must act, and limit how often | Too many nudges get muted, and the habit effect stops |
| Glance | Give the app a glance with the one key number | The glance loop is where a daily habit lives |
| Text | Short labels with units ("Sit 52 min"). No sentences on screen | A label that needs a manual is a bad label |
| Motion | No animation except progress | Battery and attention |

Check every screen change in the simulator for `fenix7pro`, and look at a screenshot before you
report it.

## 8. Output quality: no slop

1. **Code.** Comment only a reason the code cannot show. No line-by-line narration.
2. **Scope.** Do what was asked, completely, and nothing else. Name related problems in one line
   each and offer them.
3. **Replies.** Lead with the result in one or two sentences. Then a short table of what changed,
   the test result, and what is not tested. Aim for under 300 words.
4. **One question at most.** If a decision belongs to the team, ask one clear question at the end.

## 9. Done checklist

| # | Check |
|---|---|
| 1 | The build for `fenix7pro` passes with type checking on, and no new warning |
| 2 | Every caller of a changed function still works (grep done) |
| 3 | Logic is in the core, not in `onUpdate`, a delegate or a callback |
| 4 | Units in names, named constants, null checks at the boundary |
| 5 | Demo mode still works without hardware |
| 6 | One `(:test)` per risky change, run, real result reported |
| 7 | What is not tested on the watch or the board is written down |
| 8 | Memory of the glance and background service checked in the simulator |
| 9 | Screen: one message, text inside the safe area, state in words, colors keep their meaning |
| 10 | Decision lines added to `main_project/DECISIONS.md` |
| 11 | Reply: result first, under 300 words, at most one question |
