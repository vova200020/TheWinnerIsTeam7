#!/bin/zsh
# Builds stage copies of the watch app + face with demo mode ON by default
# (sideloaded apps can't have their settings changed from the phone).
# Output: stage/FocusBar.prg, stage/FocusFace.prg  → copy both to GARMIN/APPS on the watch.
set -euo pipefail
cd "$(dirname "$0")"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
DEVICE="${1:-fenix7pro}"
TMP=$(mktemp -d)
cp -R app face shared "$TMP/"
for p in app face; do
  sed -i '' 's/<property id="demoMode" type="boolean">false/<property id="demoMode" type="boolean">true/' "$TMP/$p/resources/settings/properties.xml"
done
mkdir -p stage
(cd "$TMP/app"  && "$SDK/bin/monkeyc" -f monkey.jungle -d "$DEVICE" -o "$OLDPWD/stage/FocusBar.prg"  -y "$OLDPWD/../developer_key.der")
(cd "$TMP/face" && "$SDK/bin/monkeyc" -f monkey.jungle -d "$DEVICE" -o "$OLDPWD/stage/FocusFace.prg" -y "$OLDPWD/../developer_key.der" 2>&1 | grep -v "Glance applications")
rm -rf "$TMP"
ls -la stage
