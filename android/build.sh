#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=== Building MacConnect Android APK (Universal Compatibility) ==="

# Paths
export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
export PATH="$JAVA_HOME/bin:$PATH"

SDK_ROOT="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
BUILD_TOOLS="$SDK_ROOT/build-tools/35.0.0"
PLATFORM="$SDK_ROOT/platforms/android-36/android.jar"

if [ ! -f "$PLATFORM" ]; then
    echo "Error: android.jar not found at $PLATFORM"
    exit 1
fi

rm -rf build
mkdir -p build/compiled_res build/gen build/classes bin

echo "[1/7] Compiling resources with aapt2..."
"$BUILD_TOOLS/aapt2" compile --dir src/main/res -o build/compiled_res.zip

echo "[2/7] Linking resources and generating R.java..."
"$BUILD_TOOLS/aapt2" link -I "$PLATFORM" \
    --min-sdk-version 21 \
    --target-sdk-version 33 \
    --version-code 4 \
    --version-name "1.1.0" \
    --manifest src/main/AndroidManifest.xml \
    -o build/base.apk \
    --java build/gen \
    --auto-add-overlay \
    build/compiled_res.zip

echo "[3/7] Compiling Java source files with javac (Java 8 bytecode)..."
javac --release 8 \
    -cp "$PLATFORM" \
    -d build/classes \
    $(find build/gen -name "*.java") \
    $(find src/main/java -name "*.java")

echo "[4/7] Generating classes.dex with d8 (min-api 21)..."
"$BUILD_TOOLS/d8" --min-api 21 \
    --output build/ \
    --lib "$PLATFORM" \
    $(find build/classes -name "*.class")

echo "[5/7] Adding classes.dex to APK..."
cp build/base.apk build/unaligned.apk
(cd build && zip -u unaligned.apk classes.dex)

echo "[6/7] Aligning APK with zipalign..."
"$BUILD_TOOLS/zipalign" -f -p 4 build/unaligned.apk build/aligned.apk

echo "[7/7] Signing APK with apksigner (v1 + v2 + v3 enabled)..."
if [ ! -f build/debug.keystore ]; then
    keytool -genkeypair -v -keystore build/debug.keystore \
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass android -keypass android \
        -dname "CN=MacConnect,O=MacConnect,C=US"
fi

"$BUILD_TOOLS/apksigner" sign \
    --ks build/debug.keystore \
    --ks-pass pass:android \
    --key-pass pass:android \
    --min-sdk-version 21 \
    --v1-signing-enabled true \
    --v2-signing-enabled true \
    --v3-signing-enabled true \
    --out bin/MacConnect.apk \
    build/aligned.apk

cp bin/MacConnect.apk ../MacConnect.apk

echo ""
echo "=== Build Succeeded! ==="
ls -lh bin/MacConnect.apk
echo "Output APK: $DIR/bin/MacConnect.apk and ../MacConnect.apk"
