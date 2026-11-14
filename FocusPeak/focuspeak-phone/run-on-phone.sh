#!/usr/bin/env bash
# Loads the FocusPeak Expo app onto the Android phone over USB (Git Bash on this laptop).
# Needs: phone on USB with USB debugging allowed, and Expo Go installed on the phone.
# The routes go over the cable, so the venue Wi-Fi and the Windows firewall do not matter:
#   8081 = Expo dev server (the app code), 8787 = FocusPeak backend (fetch("http://localhost:8787/...")).
set -u
PT="$LOCALAPPDATA/Microsoft/WinGet/Packages/Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe"
ADB="$PT/platform-tools/adb.exe"
export ANDROID_HOME="$PT"                 # Expo finds adb under ANDROID_HOME/platform-tools
export PATH="$PT/platform-tools:$PATH"
cd "$(dirname "$0")"

"$ADB" get-state >/dev/null 2>&1 || { echo "No phone: plug it in and tap Allow on the USB debugging prompt"; exit 1; }

# Samsung prints a harmless "user 150" error (Secure Folder) on pm list: keep stderr out.
"$ADB" shell pm list packages 2>/dev/null | grep -q host.exp.exponent || { echo "Expo Go is not installed on the phone"; exit 1; }

# Routes reset on each replug, so set them every time.
"$ADB" reverse tcp:8081 tcp:8081 >/dev/null
"$ADB" reverse tcp:8787 tcp:8787 >/dev/null
echo "Routes: $("$ADB" reverse --list | tr '\n' ' ')"

if curl -s -m 3 http://127.0.0.1:8081/status | grep -q running; then
  # A Metro server already runs (maybe in another terminal): only open the app on the phone.
  "$ADB" shell am start -a android.intent.action.VIEW -d "exp://127.0.0.1:8081" host.exp.exponent >/dev/null
  echo "Opened FocusPeak in Expo Go (existing server on 8081)"
else
  # --android opens the app in Expo Go on the phone. Without CI mode, saving a file reloads the app.
  npx expo start --localhost --android
fi
