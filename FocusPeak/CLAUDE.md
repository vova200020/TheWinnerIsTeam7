# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Workspace for the **Tech Thursday x Garmin hackathon** ("Hack West"): Saturday 2026-11-14 at Platform
Calgary (407 9 Ave SE, starts in the East Annex). The deliverable is a Garmin **Connect IQ** app in
**Monkey C** for the **Fenix 7 Pro** (device id `fenix7pro`), built with **Connect IQ SDK 9.1.0**. The
organizers require 9.1.0, not the newest SDK. Optional hardware the participant owns: a Nordic
nRF52840-DK, a USB host shield with a MAX3421E, and an Infineon BGT60TR13C 60 GHz radar kit.

Start every session with `START_HERE.md` (current state, read order, change ledger), then `MAP.md`
(where each workstream lives). The folder is not a git repository yet.

## Event rules that shape the work

| Rule (from the organizers) | What it means for Claude |
|---|---|
| Ideas may be prepared, but nothing already built | Write no app or firmware code for the project before the event. Setup, research and throwaway checks in the scratchpad are fine |
| Problem statement and random teams are announced on the day | Keep preparation generic. Map every idea to the judging criteria |
| Pitch: 3 minutes plus questions, pitching starts at 4 pm | Use the `presentation` skill. Freeze the demo path at least 45 minutes before |
| Judging, 0 to 5 each: Problem-Solution Fit, Execution and Deployment ("Does it work? Is there a live deployment we can test?"), User Experience and Design, Impact and Value ("impacting people's habits"), Creativity and Approach | A working demo on a real watch beats extra features. Habit change is the scored outcome |
| Prizes: 1st $1,000 plus Garmin watches, 2nd $500 | None |

## Layout

| Path | What it holds |
|---|---|
| `main_project/` | The hackathon app (empty until the event). Holds `DECISIONS.md` once work starts |
| `test_project/developer_key` | The Connect IQ signing key (DER-encoded PKCS#8 RSA, binary). Sign every build with `-y`. Never print, regenerate or commit it |
| `hardware/` | Optional boards: vendor docs, cloned code and one `FINDINGS.md` per board |
| `research/` | Research on the event: past editions, judging, likely themes, Connect IQ capabilities |
| `.claude/skills/` | Project skills (table below) |
| `connectiq-sdk-manager-windows/` and its `.zip` | The vendor SDK Manager GUI. Not project code: ignore it in searches |

## Connect IQ toolchain (installed outside the repo)

- SDK root: `%APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b` (active in
  `current-sdk.cfg`). SDK 9.3.0 is also installed: do not build with it. Tools are in `<SDK>\bin\` and
  are **not on PATH**. Use the `.bat` wrappers. The Java 1.8 on PATH works with this compiler.
- `fenix7pro` facts from the SDK device files (`%APPDATA%\Garmin\ConnectIQ\Devices\fenix7pro\`):
  Connect IQ 5.2.0, 260 x 260 round memory-in-pixel (MIP) display, touchscreen, app keys enter /
  up (hold for menu) / down / back. Memory: watch app 768 KB, data field 256 KB, watch face 128 KB,
  glance 64 KB, background service 64 KB. Background temporal events run at most every 5 minutes.
- Test watch on hand: **Forerunner 265** (`fr265`): Connect IQ 5.2.0, 416 x 416 round AMOLED, same
  memory limits. Build for both devices; the event judges the Fenix 7 Pro.
- Useful SDK samples to start from: `<SDK>\samples\` (`SensorHistory`, `ActivityTracking`,
  `BackgroundTimer`, `Attention`, `Notifications`, `Menu2Sample`, `WebRequest`, `NordicThingy52` for
  Bluetooth Low Energy). Their manifests do not list `fenix7pro`: add `<iq:product id="fenix7pro"/>`
  inside `<iq:products>`.
- VS Code with the official Garmin Monkey C extension (`garmin.monkey-c`) is installed. Do not use the
  community Monkey C extensions (organizer warning).

## Commands

From Git Bash (set once per shell):

```bash
SDK="$APPDATA/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b/bin"
KEY="D:/Projects/Hackathon_Tech_Thursday_x_Garmin/test_project/developer_key"
```

Run from the app folder (the one with `monkey.jungle`). Checked on 2026-11-13: builds for `fenix7pro`
and `fr265` (about 5 s each), and unit tests in the simulator (`prep_tests/ble_watch_receiver`, 4 of 4
pass). Use `-d fr265` for the participant's own test watch.

```bash
# Build for the Fenix 7 Pro (-l 2 = informative type checking, or set project.typecheck in monkey.jungle)
"$SDK/monkeyc.bat" -f monkey.jungle -d fenix7pro -o bin/app.prg -y "$KEY" -w -l 2

# Start the simulator (leave it open), then load the app into it
"$SDK/connectiq.bat"
"$SDK/monkeydo.bat" bin/app.prg fenix7pro

# Unit tests: build with -t, then run all tests or one test by name (simulator open).
# monkeydo.bat takes Windows-style /t; MSYS_NO_PATHCONV=1 stops Git Bash rewriting it into a path.
"$SDK/monkeyc.bat" -f monkey.jungle -d fenix7pro -o bin/app-test.prg -y "$KEY" -t
MSYS_NO_PATHCONV=1 "$SDK/monkeydo.bat" bin/app-test.prg fenix7pro /t
MSYS_NO_PATHCONV=1 "$SDK/monkeydo.bat" bin/app-test.prg fenix7pro /t Module.testName

# Store package (.iq) for every product in the manifest
"$SDK/monkeyc.bat" -f monkey.jungle -e -o bin/app.iq -y "$KEY" -r
```

Unit tests are functions annotated `(:test)` that take a `Logger` and return `Boolean`. The compiler
includes them only with `-t`. There is no separate linter: compiler warnings (`-w`) and type checking
(`-l 0` to `3`: off, gradual, informative, strict) are the checks.

To run the app on a real watch, copy `bin/app.prg` to `GARMIN/APPS/` on the watch over USB.

## Optional hardware

Each board has a folder under `hardware/` with `docs/`, code and a `FINDINGS.md` that holds the
verified facts, the setup steps and the open questions. Read that file before you wire or flash.

- **nRF52840-DK:** `hardware/nrf52840-dk/` is a west workspace (Zephyr v4.4.0, Zephyr SDK 1.0.1 in
  `~/zephyr-sdk-1.0.1`) whose manifest repo is the Embedded in Embedded (EiE) course repo
  `eie_nrf52840/` (Python env via `uv`; its `west.yml` was edited to add `mbedtls` and `tf-psa-crypto`,
  needed for Bluetooth). Run west from `eie_nrf52840/`:
  - EiE app: `uv run west build -b nrf52840dk/nrf52840 app`
  - Any other app: the EiE repo is a Zephyr module whose LED driver breaks other builds, so leave it out:
    `uv run west build -p always -b nrf52840dk/nrf52840 -d ../build_x -s <app dir> -- "-DZEPHYR_MODULES=$T/modules/hal/cmsis_6;$T/modules/hal/nordic"`
    with `T` = full path of `hardware/nrf52840-dk` (add the crypto modules to that list if the app needs Bluetooth security).
  - Flash: `uv run west flash -d <build dir> --runner jlink` (add `--recover` the first time). Needs SEGGER
    J-Link software (not installed: admin install by the user). Drag-and-drop to the DK's `JLINK` drive
    does NOT work on this board.
  - Bluetooth lessons are in `eie_nrf52840/doc/7_*` to `doc/9_*`.
- **Radar → laptop → nRF → watch chain** (hardware bring-up, not hackathon app code), all in `prep_tests/`:
  - `radar_laptop/radar_bridge.py --port COM21`: radar frames → moving points (`points.py`, tested by
    `test_points.py`) → text lines `P n x y z ...` (5 cm units) to the DK serial port. `--dry-run` prints only.
  - `ble_nrf_peripheral` (Zephyr): forwards laptop lines as 20-byte BLE notifications; synthetic data
    after 2 s without a line; advertises "HackBridge"; one connection at a time.
  - `ble_watch_receiver` (Connect IQ "BLE Test"): top-down radar view of the points; `DEMO_MODE` in
    `BleLink.mc` for the simulator.
  - `ble_laptop_client/ble_client.py` (`uv run --with bleak`): laptop BLE check of the same packets.
  - The packet format lives in `src/main.c`, `source/Packet.mc`, `points.py` and `ble_client.py`: change them together.
  - Verified 2026-11-13 on the real hardware: laptop → DK → BLE at 10 packets/s, 0 lost; a waving hand
    shows as dots on the Forerunner 265 and clears when still; left/right is a mirror view for a user facing
    the radar (`AZ_SIGN = -1` in `points.py`). Not yet checked: up/down sign (`EL_SIGN`).
  - Copy the watch app with `scratchpad`-style MTP copy into `GARMIN/Apps` (the watch is an MTP device,
    not a drive letter). If Windows shows the watch as `091E:0003` with a driver error, replug it until it
    appears as "Forerunner 265" (`091E:50A1`).
- **MAX3421E USB host shield:** `hardware/max3421e-usb-host-shield/`. Do not stack a 5 V-build shield on
  the DK: its MISO and INT lines are 5 V and the nRF52840 pins take at most 3.3 V. Identify the shield first.
- **BGT60TR13C radar:** the kit is the **DEMO BGT60TR13C** (Radar Baseboard MCU7, USB serial COM29).
  It only streams raw frames to a host that speaks Infineon's protocol, so use the Radar Development
  Kit (RDK 3.6.5, unpacked in `hardware/bgt60tr13c/sdk/rdk_3.6.5/`). Python env with the RDK wrapper:
  `prep_tests/radar_laptop/.venv` (run `.venv/Scripts/python.exe radar_check.py`). Infineon Python
  examples (presence, range-Doppler, beamforming helpers) are in
  `hardware/bgt60tr13c/sdk/rdk_3.6.5/radar_sdk/radar_sdk/examples/py/FMCW/`. Close Radar Fusion GUI
  before scripts use the radar. The ModusToolbox and KIT_CSK material in that folder does not apply.

## Skills

| Skill | Where | Use it for |
|---|---|---|
| `hackathon-code-standard` | `.claude/skills/` | All code: Monkey C, Zephyr C, Python. Demo mode, memory limits, watch UI rules, wiring safety |
| `presentation` | `.claude/skills/` | The 3-minute pitch, demo plan, deck tools (`deck_build.py`, `deck_check.py`) |
| `ste-writing` | `.claude/skills/` | Wording of documents and replies (ASD-STE100), gate `scripts/ste_check.py` |
| `ASG-audit` | `.claude/skills/` | Quick fact-check of a statistic, a Garmin API fact or a hardware spec before the team relies on it |
| `cad-skill` (`parametric-3d-printing`) | `.claude/skills/` | A 3D-printed mount or case for the boards. Rebuild its venv from `requirements.txt` first |
| `report-standard`, `md-to-pdf` | user level | Layout of reports and HTML pages, PDF output |

Documents in this repo (`START_HERE.md`, `MAP.md`, findings, reports) follow `report-standard` and
`ste-writing`: tables first, every acronym spelled out once, no em-dashes, no people named.

This is a hackathon, not a research project. Skip the academic parts of the user-level skills
(citation formats, Zotero keys, primary-PDF page checks, multi-pass audits, pre-registration).
Facts still have to be right: keep a link for anything a teammate may need to check.
