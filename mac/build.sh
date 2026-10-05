#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=== Building MacConnect for macOS ==="

mkdir -p build

echo "[1/3] Compiling Objective-C / Cocoa source files..."
clang -fobjc-arc -O2 \
    -framework Cocoa \
    -framework IOBluetooth \
    -framework UserNotifications \
    -I MacConnect \
    MacConnect/main.m \
    MacConnect/AppDelegate.m \
    MacConnect/BluetoothBridge.m \
    MacConnect/NotificationPresenter.m \
    -o build/MacConnect

echo "[2/3] Constructing MacConnect.app application bundle..."
APP_DIR="build/MacConnect.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp build/MacConnect "$APP_DIR/Contents/MacOS/MacConnect"
cp MacConnect/Info.plist "$APP_DIR/Contents/Info.plist"

if [ ! -f "build/AppIcon.icns" ]; then
    ICONSET="build/AppIcon.iconset"
    mkdir -p "$ICONSET"
    SRC="../android/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
    sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png" >/dev/null 2>&1 || true
    sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png" >/dev/null 2>&1 || true
    sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png" >/dev/null 2>&1 || true
    sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png" >/dev/null 2>&1 || true
    sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png" >/dev/null 2>&1 || true
    sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null 2>&1 || true
    iconutil -c icns "$ICONSET" -o "build/AppIcon.icns" >/dev/null 2>&1 || true
    rm -rf "$ICONSET"
fi

if [ -f "build/AppIcon.icns" ]; then
    cp build/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

echo "[3/3] Code signing application bundle..."
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "=== macOS Build Succeeded! ==="
echo "Binary: $DIR/build/MacConnect"
echo "Bundle: $DIR/build/MacConnect.app"
ls -ld "$APP_DIR"
