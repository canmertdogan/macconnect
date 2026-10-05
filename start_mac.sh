#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$DIR/mac/build/MacConnect.app"

if [ ! -d "$APP" ]; then
    echo "Building MacConnect first..."
    "$DIR/mac/build.sh"
fi

echo "Launching MacConnect in the macOS Menu Bar..."
open "$APP"
echo "MacConnect is now running in your menu bar (look for the 📱 icon in the top right)."
