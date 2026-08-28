#!/bin/bash
# Builds a styled galleRE.dmg with a drag-to-Applications layout.
# Requires galleRE.app to exist (run ./build_app.sh --universal first).
set -e
cd "$(dirname "$0")"

APP="galleRE.app"
VOL="galleRE"
DMG="galleRE.dmg"
BG="dmg_background.png"

[ -d "$APP" ] || { echo "✗ $APP not found — run ./build_app.sh --universal first"; exit 1; }
[ -f "$BG" ]  || { echo "✗ $BG not found — run: swift dmg_background.swift"; exit 1; }

echo "▸ Staging…"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
mkdir "$STAGING/.background"
cp "$BG" "$STAGING/.background/background.png"

echo "▸ Creating writable image…"
rm -f rw.dmg "$DMG"
hdiutil create -srcfolder "$STAGING" -volname "$VOL" -fs HFS+ \
  -format UDRW -ov rw.dmg >/dev/null

echo "▸ Mounting…"
DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen rw.dmg | egrep '^/dev/' | sed 1q | awk '{print $1}')"
sleep 2

echo "▸ Applying Finder layout…"
osascript <<EOF || echo "  (Finder styling skipped — DMG still works, just unstyled)"
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set background picture of opts to file ".background:background.png"
    set position of item "$APP" of container window to {165, 205}
    set position of item "Applications" of container window to {495, 205}
    update without registering applications
    delay 2
    close
  end tell
end tell
EOF

sync
echo "▸ Finalizing…"
hdiutil detach "$DEVICE" >/dev/null || hdiutil detach "$DEVICE" -force >/dev/null
hdiutil convert rw.dmg -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f rw.dmg
rm -rf "$STAGING"

echo "✓ Built $DMG"
ls -lh "$DMG"
