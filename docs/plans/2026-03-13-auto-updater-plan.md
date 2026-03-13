# Auto Updater Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add automatic update checking via Sparkle 2, so users are prompted when a new release is available on GitHub.

**Architecture:** Sparkle 2 integrated via SPM. `UpdateManager` wraps `SPUStandardUpdaterController` and is owned by `AppDelegate`. Appcast XML hosted on GitHub Pages, DMGs on GitHub Releases. Release script signs updates with EdDSA and publishes the appcast.

**Tech Stack:** Sparkle 2 (SPM), GitHub Pages, EdDSA signing

**Testing note:** This feature is pure configuration and integration — `UpdateManager` is ~10 lines wrapping Sparkle with no app logic. No automated tests. Verification is manual: build a release, publish an appcast, confirm the update dialog appears.

---

### Task 1: Add Sparkle SPM dependency

**Files:**
- Modify: `project.yml`

**Step 1: Add Sparkle package and dependency to project.yml**

Add the `packages` block at the top level (after `settings`), and add Sparkle as a dependency to the Countdown target:

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.0.0"
```

In `targets.Countdown`, add a `dependencies` section:

```yaml
    dependencies:
      - package: Sparkle
```

**Step 2: Regenerate the Xcode project**

Run: `xcodegen generate`
Expected: `Project generated` success message

**Step 3: Build to verify Sparkle links**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build -quiet`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add project.yml Countdown.xcodeproj
git commit -m "Add Sparkle 2 as SPM dependency"
```

---

### Task 2: Add Info.plist keys for Sparkle

**Files:**
- Modify: `Countdown/Info.plist`

**Step 1: Add SUFeedURL and SUEnableAutomaticChecks**

Add these keys inside the top-level `<dict>` in `Countdown/Info.plist`:

```xml
<key>SUFeedURL</key>
<string>https://tavva.github.io/countdown/appcast.xml</string>
<key>SUEnableAutomaticChecks</key>
<true/>
```

Leave `SUPublicEDKey` out for now — it will be added after the one-time key generation step (Task 8).

**Step 2: Build to verify**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Countdown/Info.plist
git commit -m "Add Sparkle appcast URL and auto-check to Info.plist"
```

---

### Task 3: Create UpdateManager

**Files:**
- Create: `Countdown/UpdateManager.swift`

**Step 1: Write UpdateManager.swift**

```swift
// ABOUTME: Manages automatic update checking via Sparkle.
// ABOUTME: Wraps SPUStandardUpdaterController for programmatic use without XIBs.

import Sparkle

@MainActor
final class UpdateManager {
    let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Countdown/UpdateManager.swift
git commit -m "Add UpdateManager wrapping Sparkle updater"
```

---

### Task 4: Wire UpdateManager into AppDelegate

**Files:**
- Modify: `Countdown/AppDelegate.swift:1-13`

**Step 1: Add UpdateManager property to AppDelegate**

Add `import Sparkle` is not needed (UpdateManager handles it). Add the property alongside `calendarManager`:

```swift
let updateManager = UpdateManager()
```

Place it after the `calendarManager` property declaration (line 13), before `overlayPanel`.

**Step 2: Build to verify**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build -quiet`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Countdown/AppDelegate.swift
git commit -m "Wire UpdateManager into AppDelegate"
```

---

### Task 5: Add "Check for Updates" to SettingsView

**Files:**
- Modify: `Countdown/SettingsView.swift`
- Modify: `Countdown/CountdownApp.swift`

**Step 1: Add updateManager parameter to SettingsView**

Change the `SettingsView` struct to accept an `UpdateManager`:

```swift
struct SettingsView: View {
    @Bindable var manager: CalendarManager
    let updateManager: UpdateManager
```

**Step 2: Add "Check for Updates" button**

In the `body`, add a button between the "Launch at login" toggle and the bottom HStack (the section with "Google Calendar is a trademark..." and "Quit"). Add a divider before it:

```swift
Divider()

Button("Check for Updates…") {
    updateManager.checkForUpdates()
}
.disabled(!updateManager.canCheckForUpdates)
```

**Step 3: Update SettingsView call sites**

In `CountdownApp.swift` (line 12), update the `MenuBarExtra` content:

```swift
SettingsView(manager: appDelegate.calendarManager, updateManager: appDelegate.updateManager)
```

In `AppDelegate.swift`, in `showSettingsPanel()` (around line 127), update:

```swift
panel.contentView = NSHostingView(rootView: SettingsView(manager: calendarManager, updateManager: updateManager))
```

**Step 4: Build to verify**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build -quiet`
Expected: BUILD SUCCEEDED

**Step 5: Run tests to check nothing is broken**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test -quiet`
Expected: All tests pass

**Step 6: Commit**

```bash
git add Countdown/SettingsView.swift Countdown/CountdownApp.swift Countdown/AppDelegate.swift
git commit -m "Add Check for Updates button to settings"
```

---

### Task 6: Create Sparkle tools download script

**Files:**
- Create: `scripts/download-sparkle-tools.sh`
- Modify: `.gitignore`

**Step 1: Add sparkle-tools to .gitignore**

Append to `.gitignore`:

```
# Sparkle CLI tools (downloaded binary)
scripts/sparkle-tools/
```

**Step 2: Create the download script**

Create `scripts/download-sparkle-tools.sh`:

```bash
#!/bin/bash
# ABOUTME: Downloads Sparkle CLI tools (generate_keys, sign_update, generate_appcast).
# ABOUTME: Required for signing releases and generating the appcast.

set -euo pipefail

SPARKLE_VERSION="2.7.5"
TOOLS_DIR="$(dirname "$0")/sparkle-tools"
SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"

if [ -d "$TOOLS_DIR/bin" ]; then
  echo "Sparkle tools already present at $TOOLS_DIR/bin"
  exit 0
fi

echo "==> Downloading Sparkle ${SPARKLE_VERSION} tools..."
TEMP_DIR=$(mktemp -d)
curl -sL "$SPARKLE_URL" -o "$TEMP_DIR/sparkle.tar.xz"

echo "==> Extracting..."
mkdir -p "$TOOLS_DIR"
tar -xf "$TEMP_DIR/sparkle.tar.xz" -C "$TEMP_DIR"
cp -R "$TEMP_DIR/bin" "$TOOLS_DIR/bin"

rm -rf "$TEMP_DIR"
echo "==> Sparkle tools installed to $TOOLS_DIR/bin"
echo "    generate_keys, sign_update, generate_appcast available."
```

Make it executable: `chmod +x scripts/download-sparkle-tools.sh`

**Step 3: Commit**

```bash
git add scripts/download-sparkle-tools.sh .gitignore
git commit -m "Add script to download Sparkle CLI tools"
```

---

### Task 7: Update build-release.sh for EdDSA signing and appcast

**Files:**
- Modify: `scripts/build-release.sh`

**Step 1: Add EdDSA signing after notarisation**

After the stapling step (line 93) and before the tagging step (line 95), add:

```bash
echo "==> Signing DMG with EdDSA..."
SPARKLE_TOOLS="$(dirname "$0")/sparkle-tools/bin"
if [ ! -f "$SPARKLE_TOOLS/sign_update" ]; then
  echo "Error: Sparkle tools not found. Run scripts/download-sparkle-tools.sh first."
  exit 1
fi
EDDSA_SIGNATURE=$("$SPARKLE_TOOLS/sign_update" "$DMG_PATH" | head -1)
DMG_SIZE=$(stat -f%z "$DMG_PATH")

echo "==> Updating appcast..."
APPCAST_DIR="$BUILD_DIR/appcast-work"
git worktree add "$APPCAST_DIR" gh-pages 2>/dev/null || git worktree add "$APPCAST_DIR" --orphan gh-pages
APPCAST_FILE="$APPCAST_DIR/appcast.xml"

PUB_DATE=$(date -R)
DMG_URL="https://github.com/tavva/countdown/releases/download/${TAG}/Countdown-${VERSION}.dmg"

# Create appcast if it doesn't exist
if [ ! -f "$APPCAST_FILE" ]; then
cat > "$APPCAST_FILE" << 'APPCAST_HEADER'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Countdown Updates</title>
  </channel>
</rss>
APPCAST_HEADER
fi

# Build the new item XML
NEW_ITEM=$(cat << ITEM_EOF
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure url="${DMG_URL}"
                 type="application/octet-stream"
                 ${EDDSA_SIGNATURE}
                 length="${DMG_SIZE}" />
    </item>
ITEM_EOF
)

# Insert new item before </channel>
awk -v item="$NEW_ITEM" '/<\/channel>/ { print item } { print }' "$APPCAST_FILE" > "$APPCAST_FILE.tmp"
mv "$APPCAST_FILE.tmp" "$APPCAST_FILE"

# Commit and push appcast
cd "$APPCAST_DIR"
git add appcast.xml
git commit -m "Update appcast for ${TAG}"
git push origin gh-pages
cd -

git worktree remove "$APPCAST_DIR"
```

**Note on `sign_update` output:** Sparkle's `sign_update` outputs an attribute string like `sparkle:edSignature="..." length="..."`. However, since we compute length separately, we use `head -1` and extract just the signature line. Check the actual output format when implementing — it may output `sparkle:edSignature="..."` as a single line that can be dropped directly into the enclosure attributes. Adjust the awk/sed as needed.

**Step 2: Build-test the script syntax**

Run: `bash -n scripts/build-release.sh`
Expected: No syntax errors

**Step 3: Commit**

```bash
git add scripts/build-release.sh
git commit -m "Add EdDSA signing and appcast generation to release script"
```

---

### Task 8: Generate EdDSA keys and set up GitHub Pages

This task has manual steps that require Ben's involvement.

**Step 1: Download Sparkle tools**

Run: `./scripts/download-sparkle-tools.sh`

**Step 2: Generate EdDSA keypair**

Run: `./scripts/sparkle-tools/bin/generate_keys`

This stores the private key in the login Keychain and prints the public key. Copy the public key string.

**Step 3: Add SUPublicEDKey to Info.plist**

Add to `Countdown/Info.plist`:

```xml
<key>SUPublicEDKey</key>
<string>PASTE_PUBLIC_KEY_HERE</string>
```

**Step 4: Create gh-pages branch**

```bash
git checkout --orphan gh-pages
git rm -rf .
echo "Sparkle appcast hosting" > README.md
git add README.md
git commit -m "Initialise GitHub Pages for appcast"
git push -u origin gh-pages
git checkout main
```

**Step 5: Enable GitHub Pages**

In the GitHub repo settings, enable Pages from the `gh-pages` branch root.

**Step 6: Commit Info.plist change**

```bash
git add Countdown/Info.plist
git commit -m "Add EdDSA public key to Info.plist"
```

**Step 7: Verify build**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build -quiet`
Expected: BUILD SUCCEEDED
