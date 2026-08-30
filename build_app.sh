#!/bin/bash
# Builds galleRE and packages it into a double-clickable .app bundle.
set -e
cd "$(dirname "$0")"

APP_NAME="galleRE"
BUNDLE_ID="com.clarkhess.gallere"
APP_VERSION="1.2.0"   # keep in sync with the GitHub release tag (vX.Y.Z)
CONFIG="release"
APP_DIR="./$APP_NAME.app"

# Pass --universal to build a fat binary (Apple Silicon + Intel) for distribution.
if [ "$1" = "--universal" ]; then
    echo "▸ Compiling universal (arm64 + x86_64)…"
    swift build -c "$CONFIG" --arch arm64
    swift build -c "$CONFIG" --arch x86_64
    ARM="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)/$APP_NAME"
    X64="$(swift build -c "$CONFIG" --arch x86_64 --show-bin-path)/$APP_NAME"
    mkdir -p .build/universal
    BIN_PATH=".build/universal/$APP_NAME"
    lipo -create "$ARM" "$X64" -output "$BIN_PATH"
    echo "  archs: $(lipo -archs "$BIN_PATH")"
else
    echo "▸ Compiling ($CONFIG)…"
    swift build -c "$CONFIG"
    BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
fi

echo "▸ Assembling $APP_DIR…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"

if [ -f "./$APP_NAME.icns" ]; then
    cp "./$APP_NAME.icns" "$APP_DIR/Contents/Resources/$APP_NAME.icns"
    echo "▸ Bundled app icon"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$APP_VERSION</string>
    <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "▸ Ad-hoc code signing…"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "  (codesign skipped)"

echo "✓ Built $APP_DIR"
echo "  Open with:  open $APP_DIR"
