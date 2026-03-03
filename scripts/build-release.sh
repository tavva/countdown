#!/bin/bash
# ABOUTME: Builds, signs, notarises, and packages the app into a DMG for distribution.
# ABOUTME: Requires a Developer ID Application certificate and stored notarisation credentials.

set -euo pipefail

VERSION="${1:?Usage: $0 <version> (e.g. 1.0.0)}"

PROJECT="Countdown.xcodeproj"
SCHEME="Countdown"
TEAM_ID="C8Q84FVJHL"
BUILD_DIR="./build"
ARCHIVE_PATH="$BUILD_DIR/Countdown.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/Countdown-${VERSION}.dmg"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-countdown-notarize}"

if ! git diff --quiet HEAD; then
  echo "Error: working tree has uncommitted changes. Commit or stash first."
  exit 1
fi

TAG="v${VERSION}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Error: tag $TAG already exists."
  exit 1
fi

rm -rf "$BUILD_DIR"

echo "==> Archiving..."
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  archive \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  -quiet

echo "==> Exporting archive..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions.plist

echo "==> Generating DMG background..."
swift scripts/create-dmg-background.swift "$BUILD_DIR/background.png"

echo "==> Creating DMG..."
DMG_TEMP="$BUILD_DIR/Countdown-temp.dmg"
hdiutil create -volname "Countdown" -fs HFS+ -size 50m -ov "$DMG_TEMP"
hdiutil attach "$DMG_TEMP" -readwrite -noautoopen

cp -R "$EXPORT_PATH/Countdown.app" "/Volumes/Countdown/"
ln -s /Applications "/Volumes/Countdown/Applications"
mkdir "/Volumes/Countdown/.background"
cp "$BUILD_DIR/background.png" "/Volumes/Countdown/.background/background.png"

echo "==> Styling DMG window..."
osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "Countdown"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 860, 600}
        delay 1
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "Countdown.app" of container window to {180, 190}
        set position of item "Applications" of container window to {480, 190}
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "/Volumes/Countdown"
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_PATH"
rm -f "$DMG_TEMP"

echo "==> Notarising..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARIZE_PROFILE" \
  --wait

echo "==> Stapling..."
xcrun stapler staple "$DMG_PATH"

echo "==> Tagging $TAG..."
git tag "$TAG"
git push origin "$TAG"

echo "==> Creating GitHub release..."
gh release create "$TAG" "$DMG_PATH" \
  --title "Countdown $TAG" \
  --generate-notes

echo "==> Done! Release $TAG published."
