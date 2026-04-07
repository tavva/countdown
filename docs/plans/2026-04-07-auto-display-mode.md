# Auto Display Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically switch between compact and standard overlay mode based on whether an external display is connected, with optional auto-repositioning to a chosen screen corner.

**Architecture:** Add a `SizeMode` enum (standard/compact/auto) to replace the boolean `compactMode`. Add `autoReposition` bool and `repositionCorner` enum to CountdownModel. Hook into the existing `screenDidChange` handler in AppDelegate to apply auto mode and repositioning when display configuration changes. The model computes an `effectiveCompactMode` bool that the rest of the app reads, keeping the change surface small.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSScreen, NSPanel)

---

### Task 1: Add SizeMode enum and model properties

**Files:**
- Modify: `Countdown/CountdownModel.swift`

**Step 1: Write failing tests for SizeMode persistence and effectiveCompactMode logic**

Create tests in `CountdownTests/CountdownModelTests.swift`. Add the new defaults keys to the `DefaultsSnapshot` at line 10.

```swift
// Add to the DefaultsSnapshot keys array:
"sizeMode", "autoReposition", "repositionCorner"

// New tests to add at the end of CountdownModelTests (before the closing brace):

// MARK: - Size mode

@Test func sizeModeDefaultsToStandard() {
    UserDefaults.standard.removeObject(forKey: "sizeMode")
    let model = CountdownModel()
    #expect(model.sizeMode == .standard)
}

@Test func sizeModeAutoUsesCompactWhenSingleScreen() {
    let model = CountdownModel()
    model.sizeMode = .auto
    model.applyAutoMode(screenCount: 1)
    #expect(model.compactMode == true)
}

@Test func sizeModeAutoUsesStandardWhenMultipleScreens() {
    let model = CountdownModel()
    model.sizeMode = .auto
    model.applyAutoMode(screenCount: 2)
    #expect(model.compactMode == false)
}

@Test func sizeModeAutoDoesNothingWhenNotAuto() {
    let model = CountdownModel()
    model.sizeMode = .standard
    model.compactMode = false
    model.applyAutoMode(screenCount: 1)
    #expect(model.compactMode == false)
}

@Test func sizeModePersists() {
    let model = CountdownModel()
    model.sizeMode = .compact
    let model2 = CountdownModel()
    #expect(model2.sizeMode == .compact)
}

@Test func sizeModeStandardSetsCompactFalse() {
    let model = CountdownModel()
    model.compactMode = true
    model.sizeMode = .standard
    #expect(model.compactMode == false)
}

@Test func sizeModeCompactSetsCompactTrue() {
    let model = CountdownModel()
    model.compactMode = false
    model.sizeMode = .compact
    #expect(model.compactMode == true)
}

// MARK: - Auto reposition

@Test func autoRepositionDefaultsToFalse() {
    UserDefaults.standard.removeObject(forKey: "autoReposition")
    let model = CountdownModel()
    #expect(model.autoReposition == false)
}

@Test func autoRepositionPersists() {
    let model = CountdownModel()
    model.autoReposition = true
    let model2 = CountdownModel()
    #expect(model2.autoReposition == true)
}

@Test func repositionCornerDefaultsToTopLeft() {
    UserDefaults.standard.removeObject(forKey: "repositionCorner")
    let model = CountdownModel()
    #expect(model.repositionCorner == .topLeft)
}

@Test func repositionCornerPersists() {
    let model = CountdownModel()
    model.repositionCorner = .bottomRight
    let model2 = CountdownModel()
    #expect(model2.repositionCorner == .bottomRight)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: Compilation errors — `SizeMode`, `sizeMode`, `applyAutoMode`, `autoReposition`, `repositionCorner`, `ScreenCorner` don't exist yet.

**Step 3: Implement SizeMode enum, ScreenCorner enum, and model properties**

In `Countdown/CountdownModel.swift`, add the enums and new properties:

```swift
// Add above the CountdownModel class:

enum SizeMode: Int {
    case standard = 0
    case compact = 1
    case auto = 2
}

enum ScreenCorner: Int {
    case topLeft = 0
    case topRight = 1
    case bottomLeft = 2
    case bottomRight = 3
}
```

Add new properties to `CountdownModel`:

```swift
var sizeMode: SizeMode {
    didSet {
        defaults.set(sizeMode.rawValue, forKey: DefaultsKey.sizeMode)
        switch sizeMode {
        case .standard: compactMode = false
        case .compact: compactMode = true
        case .auto: break  // applied by applyAutoMode when screen changes
        }
    }
}

var autoReposition: Bool {
    didSet { defaults.set(autoReposition, forKey: DefaultsKey.autoReposition) }
}

var repositionCorner: ScreenCorner {
    didSet { defaults.set(repositionCorner.rawValue, forKey: DefaultsKey.repositionCorner) }
}
```

Add to `init`:

```swift
self.sizeMode = SizeMode(rawValue: defaults.integer(forKey: DefaultsKey.sizeMode)) ?? .standard
self.autoReposition = defaults.bool(forKey: DefaultsKey.autoReposition)
self.repositionCorner = ScreenCorner(rawValue: defaults.integer(forKey: DefaultsKey.repositionCorner)) ?? .topLeft
```

Add `applyAutoMode` method:

```swift
func applyAutoMode(screenCount: Int) {
    guard sizeMode == .auto else { return }
    compactMode = screenCount <= 1
}
```

Add to `DefaultsKey`:

```swift
static let sizeMode = "sizeMode"
static let autoReposition = "autoReposition"
static let repositionCorner = "repositionCorner"
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: All tests pass.

**Step 5: Commit**

```
feat: add SizeMode, ScreenCorner enums and model properties
```

---

### Task 2: Add positionInCorner method to OverlayPanel

**Files:**
- Modify: `Countdown/OverlayPanel.swift`
- Modify: `CountdownTests/OverlayPositionTests.swift`

**Step 1: Write failing tests for corner positioning logic**

Add a pure function `OverlayPosition.cornerOrigin` that computes the origin for a given corner, screen frame, and panel size — this is testable without an actual panel. Add tests to `OverlayPositionTests`:

```swift
// MARK: - Corner positioning

@Test func cornerOriginTopLeft() {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let panelSize = CGSize(width: 200, height: 120)
    let origin = OverlayPosition.cornerOrigin(corner: .topLeft, visibleFrame: screen, panelSize: panelSize)
    #expect(origin.x == 20)
    #expect(origin.y == 1080 - 120 - 20)
}

@Test func cornerOriginTopRight() {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let panelSize = CGSize(width: 200, height: 120)
    let origin = OverlayPosition.cornerOrigin(corner: .topRight, visibleFrame: screen, panelSize: panelSize)
    #expect(origin.x == 1920 - 200 - 20)
    #expect(origin.y == 1080 - 120 - 20)
}

@Test func cornerOriginBottomLeft() {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let panelSize = CGSize(width: 200, height: 120)
    let origin = OverlayPosition.cornerOrigin(corner: .bottomLeft, visibleFrame: screen, panelSize: panelSize)
    #expect(origin.x == 20)
    #expect(origin.y == 20)
}

@Test func cornerOriginBottomRight() {
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let panelSize = CGSize(width: 200, height: 120)
    let origin = OverlayPosition.cornerOrigin(corner: .bottomRight, visibleFrame: screen, panelSize: panelSize)
    #expect(origin.x == 1920 - 200 - 20)
    #expect(origin.y == 20)
}

@Test func cornerOriginRespectsScreenOffset() {
    let screen = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
    let panelSize = CGSize(width: 200, height: 120)
    let origin = OverlayPosition.cornerOrigin(corner: .topLeft, visibleFrame: screen, panelSize: panelSize)
    #expect(origin.x == 1920 + 20)
    #expect(origin.y == 1440 - 120 - 20)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: Compilation error — `cornerOrigin` doesn't exist.

**Step 3: Implement `cornerOrigin` and `positionInCorner`**

Add to `OverlayPosition` enum in `OverlayPanel.swift`:

```swift
static func cornerOrigin(corner: ScreenCorner, visibleFrame: CGRect, panelSize: CGSize) -> CGPoint {
    let padding: CGFloat = 20
    let x: CGFloat
    let y: CGFloat

    switch corner {
    case .topLeft:
        x = visibleFrame.minX + padding
        y = visibleFrame.maxY - panelSize.height - padding
    case .topRight:
        x = visibleFrame.maxX - panelSize.width - padding
        y = visibleFrame.maxY - panelSize.height - padding
    case .bottomLeft:
        x = visibleFrame.minX + padding
        y = visibleFrame.minY + padding
    case .bottomRight:
        x = visibleFrame.maxX - panelSize.width - padding
        y = visibleFrame.minY + padding
    }

    return CGPoint(x: x, y: y)
}
```

Add to `OverlayPanel` class:

```swift
func positionInCorner(_ corner: ScreenCorner) {
    guard let screen = self.screen ?? NSScreen.main else { return }
    let origin = OverlayPosition.cornerOrigin(
        corner: corner,
        visibleFrame: screen.visibleFrame,
        panelSize: frame.size
    )
    setFrameOrigin(origin)
    OverlayPosition.save(origin)
}
```

Update existing `positionTopLeft()` to delegate:

```swift
func positionTopLeft() {
    positionInCorner(.topLeft)
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: All tests pass.

**Step 5: Commit**

```
feat: add corner positioning for overlay panel
```

---

### Task 3: Hook screenDidChange to apply auto mode and reposition

**Files:**
- Modify: `Countdown/AppDelegate.swift`

**Step 1: Update screenDidChange handler**

Replace the existing `screenDidChange` method:

```swift
@objc private func screenDidChange(_ notification: Notification) {
    guard let panel = overlayPanel else { return }
    let model = calendarManager.model

    model.applyAutoMode(screenCount: NSScreen.screens.count)

    if model.autoReposition {
        panel.positionInCorner(model.repositionCorner)
        panelPlacement.record(frame: panel.frame)
    } else {
        panel.ensureOnScreen()
        panelPlacement.record(frame: panel.frame)
    }
}
```

Also add `sizeMode` to the observation tracking in `observeOverlayState()` so the panel updates when auto mode kicks in — but `compactMode` is already tracked (line 106), and `applyAutoMode` sets `compactMode`, so no change needed there.

**Step 2: Apply auto mode on launch too**

In `applicationDidFinishLaunching`, after the panel is created and `ensureOnScreen` is called (around line 76), add:

```swift
calendarManager.model.applyAutoMode(screenCount: NSScreen.screens.count)
```

This ensures the correct mode is set at startup, not just on screen change.

**Step 3: Build and verify**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build 2>&1 | tail -20`
Expected: Build succeeds.

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: All tests pass.

**Step 4: Commit**

```
feat: apply auto display mode and reposition on screen change
```

---

### Task 4: Update settings UI — three-way picker with help popover

**Files:**
- Modify: `Countdown/SettingsView.swift`

**Step 1: Replace compactMode binding with sizeMode binding**

Remove the existing `compactModeBinding` computed property (lines 102-107). Add a new binding:

```swift
private var sizeModeBinding: Binding<SizeMode> {
    Binding(
        get: { manager.model.sizeMode },
        set: { manager.model.sizeMode = $0 }
    )
}
```

**Step 2: Update the filterSection picker**

Replace the "Circle size" picker (lines 193-202) with:

```swift
HStack(spacing: 4) {
    Text("Circle size")
        .font(.subheadline)
        .foregroundStyle(.secondary)

    AutoModeHelpButton()
}
.padding(.top, 4)

Picker("", selection: sizeModeBinding) {
    Text("Standard").tag(SizeMode.standard)
    Text("Compact").tag(SizeMode.compact)
    Text("Auto").tag(SizeMode.auto)
}
.pickerStyle(.segmented)
```

**Step 3: Add the help button view**

Add a small view (can go at the bottom of SettingsView.swift or as a private struct inside the file):

```swift
private struct AutoModeHelpButton: View {
    @State private var showingHelp = false

    var body: some View {
        Button {
            showingHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingHelp, arrowEdge: .trailing) {
            Text("Auto switches to standard mode when an external display is connected, and compact mode on the built-in display alone.")
                .font(.caption)
                .frame(width: 200)
                .padding(8)
        }
    }
}
```

**Step 4: Add auto-reposition toggle and corner picker**

Below the circle size picker, add:

```swift
Toggle("Auto-reposition on display change", isOn: autoRepositionBinding)
    .toggleStyle(.switch)

if manager.model.autoReposition {
    Picker("", selection: repositionCornerBinding) {
        Text("Top left").tag(ScreenCorner.topLeft)
        Text("Top right").tag(ScreenCorner.topRight)
        Text("Bottom left").tag(ScreenCorner.bottomLeft)
        Text("Bottom right").tag(ScreenCorner.bottomRight)
    }
    .pickerStyle(.segmented)
}
```

Add the bindings:

```swift
private var autoRepositionBinding: Binding<Bool> {
    Binding(
        get: { manager.model.autoReposition },
        set: { manager.model.autoReposition = $0 }
    )
}

private var repositionCornerBinding: Binding<ScreenCorner> {
    Binding(
        get: { manager.model.repositionCorner },
        set: { manager.model.repositionCorner = $0 }
    )
}
```

**Step 5: Build and verify**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build 2>&1 | tail -20`
Expected: Build succeeds.

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: All tests pass.

**Step 6: Commit**

```
feat: add auto display mode and reposition settings UI
```

---

### Task 5: Update context menu for new size mode

**Files:**
- Modify: `Countdown/OverlayPanel.swift`

**Step 1: Consider context menu behaviour**

The right-click context menu currently has a "Compact mode" toggle. With the three-way size mode, the context menu item should cycle through Standard → Compact → Auto, or could just remain as a compact toggle that switches between standard and compact (setting sizeMode to .standard or .compact, which disables auto).

The simplest approach: keep the "Compact mode" toggle. When toggled, it sets `sizeMode` to `.compact` or `.standard` explicitly (overriding auto if it was on). This is intuitive — the user is making a manual choice, so auto should be disabled.

No test changes needed — the context menu calls `onToggleCompact` which the AppDelegate maps to `toggleCompactMode()`.

**Step 2: Update `toggleCompactMode` to also update sizeMode**

In `CountdownModel.swift`, update `toggleCompactMode`:

```swift
func toggleCompactMode() {
    compactMode.toggle()
    sizeMode = compactMode ? .compact : .standard
}
```

**Step 3: Write a test for the new toggle behaviour**

Add to `CountdownModelTests`:

```swift
@Test func toggleCompactModeUpdatesSizeMode() {
    let model = CountdownModel()
    model.sizeMode = .auto
    model.compactMode = false
    model.toggleCompactMode()
    #expect(model.compactMode == true)
    #expect(model.sizeMode == .compact)
    model.toggleCompactMode()
    #expect(model.compactMode == false)
    #expect(model.sizeMode == .standard)
}
```

**Step 4: Run tests**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: All tests pass.

**Step 5: Commit**

```
feat: context menu compact toggle overrides auto size mode
```

---

### Task 6: Final integration test and cleanup

**Step 1: Run full test suite**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: All tests pass.

**Step 2: Build the app**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build 2>&1 | tail -20`
Expected: Build succeeds.

**Step 3: Commit any remaining changes**

If any cleanup was needed, commit with an appropriate message.
