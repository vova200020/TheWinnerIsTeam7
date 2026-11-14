# LINK: how the iPhone app talks to the FocusPeak watch app

> For the Xcode team. Section 1 and 2 are the contract that the watch app implements (tag `v3`).
> Section 3 is a start guide for the iOS side and is not tested.

## 0. Status

| Part | State | Your open action |
|---|---|---|
| Watch side (send state, receive sleep) | ✅ Built, 15 of 15 unit tests pass in the simulator | None |
| Link over the air with a real iPhone | ⚠️ Not tested | Test it first, before any screen work (section 4) |
| iPhone app | ⚠️ Prototype only: `index.html` in this folder shows each screen and has `handleMessage()` | Port `handleMessage()` to Swift |

## 1. Facts you need

| Item | Value |
|---|---|
| Watch app identifier (UUID) | `fbe42636-ca59-4d56-852b-c1c53b6bc912` (from `watch/manifest.xml`) |
| Watch app name | FocusPeak |
| Transport | Connect IQ Mobile SDK for iOS. Messages go through the Garmin Connect app on the phone. No server |
| Message type | One dictionary per message. Keys are strings. Values are strings or numbers |
| Switch on the watch | Menu (hold UP), "Phone link". Off by default, because the simulator shows an error for each message when no phone is attached |
| Watch build | `watch/bin/FocusPeak-fenix7pro.prg` or `FocusPeak-fr265.prg`, copied to `GARMIN/Apps` on the watch |

## 2. The messages

### 2.1 Watch to phone

| When | Message | The phone does this |
|---|---|---|
| Ready screen comes up | `{"t":"state","s":"ready"}` | Show the idle screen. Remove any lock |
| Focus starts, then each 60 s | `{"t":"state","s":"focus","left_s":1440,"planned_s":1440}` | Show LOCKED. Count down from `left_s` locally |
| Break gate, each 2 s | `{"t":"state","s":"earn","hr":96,"target":104,"rest":58}` | Show "Move to unlock" with the live heart rate. `hr` is 0 when the watch has no reading |
| Break starts, then each 5 s | `{"t":"state","s":"break","left_s":360,"planned_s":360,"hr":98,"rest":58,"steps":40,"ok":0}` | Show the Break box. Count down locally. `hr` is the live heart rate (0 = no reading), `steps` the steps since the break began, `ok` is 1 when the heart rate is back within 20 bpm of rest |
| Block is done | `{"t":"summary","score":82,"min":24,"place":"Library","streak":5,"next_min":29}` | Add a card to the feed. `place` is an empty string when the watch has no GPS fix |

The watch sends only the newest state. If the phone is not connected, the watch drops the state and
goes on. A summary waits until the phone is connected again.

### 2.2 Phone to watch

| When | Message | The watch does this |
|---|---|---|
| App start, and after a new night is in Apple Health | `{"t":"sleep","hours":6.4}` | Uses the hours in the readiness score for the same day. Ignores values below 0 or above 24, and any other message |

Read the sleep from HealthKit (`HKCategoryTypeIdentifier.sleepAnalysis`), samples written by Garmin
Connect. Sum the "asleep" samples of last night. Send one number. Nothing else leaves the phone.

## 3. iOS side: start guide (from memory of the SDK, check each name in the SDK headers)

| Step | What |
|---|---|
| 1 | Add the Connect IQ Mobile SDK for iOS (`ConnectIQ.xcframework`) from the Garmin developer site |
| 2 | Register a URL scheme for the app in `Info.plist`, and add `gcm-ciq` to `LSApplicationQueriesSchemes` |
| 3 | At launch: `ConnectIQ.sharedInstance().initialize(withUrlScheme:uiOverrideDelegate:)` |
| 4 | Let the user pick the watch: `showDeviceSelection()`. Garmin Connect opens and returns to the app through the URL scheme. Parse the devices in `application(_:open:options:)` with `parseDeviceSelectionResponse(from:)` |
| 5 | Make the app handle: `IQApp(uuid: UUID(uuidString: "FBE42636-CA59-4D56-852B-C1C53B6BC912"), store: nil, device: device)` |
| 6 | Receive: `register(forAppMessages: app, delegate: self)`, then `receivedMessage(_:from:)` gives the dictionary. Pass it to the Swift port of `handleMessage()` |
| 7 | Send the sleep: `sendMessage(["t": "sleep", "hours": 6.4], to: app, progress: nil, completion: ...)` |

## 4. First test (10 minutes, before any screen work)

- [ ] Watch paired with the iPhone in Garmin Connect, FocusPeak open on the watch
- [ ] On the watch, hold UP and turn on "Phone link" (it is off by default) and "Demo mode", then press START
- [ ] The iOS app prints each received dictionary to the console
- [ ] Expected within 60 s: one `focus`, about ten `earn`, one or two `break`, one `summary`, one `ready`
- [ ] Send `{"t":"sleep","hours":6.4}`. On the watch, turn demo mode off and open the Inputs page (DOWN twice on the Ready screen): the last line shows "Sleep 6.4 h"

If no message arrives with a sideloaded watch app, tell the watch-app owner at once: the fallback is a
small relay server, and it needs about 30 minutes.

## 5. Real app blocking (stretch)

The Screen Time API (`FamilyControls`, `ManagedSettings`) can shield apps. Its development
entitlement can be enabled in Xcode for a test build on your own phone
(https://developer.apple.com/documentation/xcode/configuring-family-controls). On `focus`: apply the
shield. On `break` and `ready`: clear it. Do this only after section 4 passes.

## 6. Phone use during focus

Focus time means no phone time. The phone app counts each time the user leaves it while the watch is
in `focus` or `earn`, and how long. It posts `{"seconds": 20}` to `/api/away` on return. The backend
adds `"exits"` and `"away_s"` to each reply to the watch. The watch lowers the Focus score when it
saves the block: 5 points for each exit, 1 point for each 6 s away, 30 points at most
(`Scoring.phonePenalty`, same rule in `focuspeak-phone/src/logic.js`). The journal keeps both numbers.

