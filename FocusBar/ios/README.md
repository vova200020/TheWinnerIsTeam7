# FocusBar iPhone companion

A SwiftUI app plus three Screen Time extensions. It talks to the FocusBar watch app through the Connect IQ iOS SDK 1.8.0, and covers spec §4–§7 on iOS.

```
ios/
├── project.yml            XcodeGen spec (run `xcodegen` to regenerate the .xcodeproj)
├── Shared/                App Group state + shield policy, used by the app and every extension
├── App/                   Main app: WatchLink (Connect IQ), Screen Time, calendar, map, friends
├── ShieldConfig/          Custom screen on blocked apps: "Locked — earn it on your watch"
├── ShieldAction/          "Unlock with watch" button → parks the request, notifies the app
└── ActivityMonitor/       Re-locks after a 5-min unlock; clears stale sessions (runs while the app is closed)
```

## Two app targets

| Target | Signing | Blocking |
|---|---|---|
| **FocusBarCompanion** | Paid developer account (Family Controls entitlement) | Real Screen Time shields + 3 extensions |
| **FocusBarLite** | **Free Apple ID** works | Simulated in-app on the **Phone** tab. Watch messages, unlock challenge, calendar, map and friends are real |

To install Lite on your iPhone, see [../STAGE-SETUP.md](../STAGE-SETUP.md).
Launch argument `-demoStart deep|medium|light` starts a pretend session (rehearsal).

## Build

```sh
cd FocusBar/ios
xcodegen generate
open FocusBarCompanion.xcodeproj      # or build from the command line:
xcodebuild -project FocusBarCompanion.xcodeproj -scheme FocusBarCompanion \
  -destination 'generic/platform=iOS Simulator' -clonedSourcePackagesDirPath .spm \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

**On a real iPhone** (needed for Screen Time and for talking to a watch):
1. Set `DEVELOPMENT_TEAM` in `project.yml`, or pick your team in Xcode for all 4 targets.
2. Change `com.focusbar.*` and `group.com.focusbar.companion` to IDs under your team.
3. Turn on the **Family Controls** capability. The *Development* entitlement works for any paid developer account. Distributing on the App Store needs Apple's approval.
4. Install Garmin Connect on the phone, pair the watch, and sideload `FocusBar/app/bin/FocusBar.prg` to the watch.

Launch argument `-tab map|detox|friends|today` opens a tab directly, which is useful for screenshots.

## How each feature maps to iOS

| Spec feature | iOS implementation | Limitation |
|---|---|---|
| Light: DND | The app reminds you to turn on Do Not Disturb | iOS has **no API to switch Focus/DND on** |
| Medium: block apps | `ManagedSettingsStore` shields the user's "Distracting apps" selection | Needs Screen Time authorization (real device) |
| Deep: allow-list only | Shields **all** categories except the "Always allowed" selection | Contact allow-lists are set in iOS Focus settings, not by apps |
| Emergency bypass (§5.2) | Apps in "Always allowed" are never shielded, and **Stop blocking now** is always available | — |
| HR-to-unlock (§5) | Shield button → App Group + notification → app sends `unlock_request` → watch → `unlock_granted` → shield lifted for 5 min → monitor extension re-locks | The user taps one notification, because extensions can't reach the watch |
| Never stuck locked | A `DeviceActivity` safety schedule clears shields 30 min after the planned end (4 h for open sessions) | — |
| Scheduled sessions (§3.1) | `#focus` calendar events → `schedule` message to the watch + a reminder notification at the start time. The watch home screen shows "Next: Thu 14:00 writing" | The watch can't auto-start (only one background timer is allowed) |
| Community map (§6) | MapKit with **mock** cells, geohash-7 snapping, k-anonymity filter (≥5 users), "Find me a spot" | No backend yet (MVP item 6) |
| Friends (§7) | Team goal, leaderboard by minutes or consistency, weekly challenges built from your real session history | Friends are mocked |

## Watch ⇄ phone messages (spec §4.2)

| Direction | `t` | Phone does |
|---|---|---|
| watch → phone | `session_start {tag, level, len}` | Applies shields and the safety schedule |
| watch → phone | `session_end {dur, avg, self}` | Clears shields and saves history |
| watch → phone | `unlock_granted {app, mins}` | Lifts the waiting app's shield for `mins` |
| phone → watch | `unlock_request {app}` | (Watch opens the HR challenge) |
| phone → watch | `schedule {sessions:[{start,len,tag}]}` | (Watch shows the next planned session) |

Messages only reach the watch app while it's open. If a send fails, the phone asks the watch to open the app (`openAppRequest`) and retries 3 times.

## Demo without a watch

The **Today** tab has *Demo without a watch*: Light / Medium / Deep / end session. These buttons play the watch's messages locally, so you can rehearse the phone side, including real shields on a device.
