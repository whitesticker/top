#!/bin/bash
# Build script for "top" — menu bar system monitor.
# No Xcode required: compiles with swiftc against a matching SDK and
# assembles a .app bundle manually, then ad-hoc codesigns it.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="top"
BUNDLE_ID="com.local.top"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

# Pick an SDK that matches the swiftc compiler version. The default
# MacOSX.sdk symlink may point at a newer beta SDK the compiler can't read.
SDK=""
for candidate in MacOSX15.5.sdk MacOSX15.4.sdk MacOSX15.sdk MacOSX14.5.sdk; do
    p="/Library/Developer/CommandLineTools/SDKs/$candidate"
    [ -d "$p" ] && SDK="$p" && break
done
if [ -z "$SDK" ]; then
    SDK="$(xcrun --sdk macosx --show-sdk-path)"
fi
echo "Using SDK: $SDK"

TARGET="arm64-apple-macosx13.0"

echo "Compiling..."
mkdir -p "$MACOS_DIR" "$RES_DIR"
# shellcheck disable=SC2046
swiftc \
    -sdk "$SDK" \
    -target "$TARGET" \
    -O \
    -framework AppKit \
    -framework SwiftUI \
    -framework IOKit \
    $(find Sources/top -name '*.swift') \
    -o "$MACOS_DIR/$APP_NAME"

echo "Writing Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Local build</string>
</dict>
</plist>
PLIST

echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "Done: $APP_DIR"
