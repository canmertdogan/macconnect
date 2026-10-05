#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK="$DIR/android/bin/MacConnect.apk"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"

if [ ! -f "$APK" ]; then
    echo "Error: APK not found at $APK. Run android/build.sh first."
    exit 1
fi

if [ ! -x "$ADB" ]; then
    ADB="adb"
fi

echo "Looking for connected Android device..."
DEVICES=$("$ADB" devices | grep -v "List" | grep "device$" || true)

if [ -z "$DEVICES" ]; then
    echo ""
    echo "No Android device detected via adb."
    echo ""
    echo "You can install the APK in one of the following ways:"
    echo "1. Connect your phone via USB with USB Debugging enabled, then re-run this script."
    echo "2. AirDrop / send the APK file to your phone: $APK"
    echo "3. Copy the APK file to Google Drive, Telegram Saved Messages, or local file transfer."
    exit 1
fi

echo "Installing MacConnect.apk onto connected device..."
"$ADB" install -r "$APK"
echo "Installation complete!"
echo "Now open 'MacConnect' on your phone and tap 'Enable' for Notification Access."
