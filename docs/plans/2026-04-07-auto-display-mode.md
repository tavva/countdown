# Auto Display Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically switch between compact and standard overlay mode based on whether an external display is connected, with optional auto-repositioning to a user-chosen screen corner that remains pinned across resizes.

**Architecture:** `SizeMode` enum (`.standard`, `.compact`, `.auto`) replaces the persisted `compactMode` boolean as the authoritative user preference. `compactMode` becomes an effective derived state, set via `applyEffectiveMode(hasExternalDisplay:)`. External-display detection uses `CGDisplayIsBuiltin` to correctly handle clamshell mode. `OverlayFramePlacement` is refactored to be anchor-aware so the panel stays pinned to the configured corner across content-size and mode changes. AppDelegate observes model changes and applies the effective mode + repositioning immediately on launch, on screen change, and on settings changes.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSScreen, NSPanel), CoreGraphics (CGDisplayIsBuiltin)

---

### Task 1: Add external display detection helper

**Files:**
- Create: `Countdown/DisplayDetection.swift`
- Test: `CountdownTests/DisplayDetectionTests.swift`

**Why this matters:** `NSScreen.screens.count > 1` is NOT equivalent to "external display connected". In clamshell mode (laptop lid closed with external monitor), count is 1 but the single screen is external. Must use `CGDisplayIsBuiltin` to check each screen.

**Step 1: Write the failing test**

Create `CountdownTests/DisplayDetectionTests.swift`:

```swift
// ABOUTME: Tests for the external display detection helper.
// ABOUTME: Verifies the pure logic that determines if any screen is non-built-in.

import Testing
import Foundation
@testable import Countdown

@Suite("DisplayDetection")
struct DisplayDetectionTests {
    @Test func noScreensMeansNoExternal() {
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: []) == false)
    }

    @Test func onlyBuiltinMeansNoExternal() {
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: [true]) == false)
    }

    @Test func onlyExternalMeansHasExternal() {
        // Clamshell mode: laptop lid closed, only external connected
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: [false]) == true)
    }

    @Test func builtinPlusExternalMeansHasExternal() {
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: [true, false]) == true)
    }

    @Test func multipleExternalsMeansHasExternal() {
        #expect(DisplayDetection.hasExternalDisplay(isBuiltinFlags: [true, false, false]) == true)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -30`
Expected: Compilation error — `DisplayDetection` doesn't exist.

**Step 3: Create `Countdown/DisplayDetection.swift`**

```swift
// ABOUTME: Detects whether any connected screen is a non-built-in (external) display.
// ABOUTME: Required to correctly handle clamshell mode where only an external display is active.

import AppKit
import CoreGraphics

enum DisplayDetection {
    /// Pure function for testability — takes an array of "is built-in" flags.
    static func hasExternalDisplay(isBuiltinFlags: [Bool]) -> Bool {
        isBuiltinFlags.contains(false)
    }

    /// Queries NSScreen and CGDisplay to determine if any connected screen is external.
    @MainActor
    static func hasExternalDisplay() -> Bool {
        let flags = NSScreen.screens.map { screen -> Bool in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            return CGDisplayIsBuiltin(displayID) != 0
        }
        return hasExternalDisplay(isBuiltinFlags: flags)
    }
}
```

**Step 4: Add file to `project.yml` sources if needed**

Check if `project.yml` has a manual source list or globs everything. If globs, no change. Otherwise add both files.

Run: `xcodegen generate` (only if project.yml changed).

**Step 5: Run tests to verify they pass**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -30`
Expected: All tests pass.

**Step 6: Commit**

```
feat: add external display detection helper
```

---

### Task 2: Add SizeMode, ScreenCorner, and effective mode logic to CountdownModel

**Files:**
- Modify: `Countdown/CountdownModel.swift`
- Modify: `CountdownTests/CountdownModelTests.swift`

**Why this matters:** The existing `compactMode` boolean is persisted. Adding a second persisted `sizeMode` while keeping persisted `compactMode` creates two sources of truth and breaks on upgrade. Solution:
- `sizeMode` becomes the persisted user preference (source of truth).
- `compactMode` stays as an observable effective state the rest of the app reads. It remains a public `var` so existing layout tests that set it directly still compile, but its `didSet` no longer writes to UserDefaults — production code routes changes through `sizeMode` and `applyEffectiveMode`.
- On init, migrate from the old `compactMode` defaults key to `sizeMode` if `sizeMode` isn't set yet.
- `sizeMode.didSet` updates `compactMode` immediately for `.standard` and `.compact` so settings changes take effect without waiting for the observation round-trip. `.auto` is handled by `applyEffectiveMode` from AppDelegate, which has access to NSScreen.

**Step 1: Write failing tests**

Add to `CountdownTests/CountdownModelTests.swift`. First, update the `DefaultsSnapshot` keys at line 10:

```swift
private let _snapshot = DefaultsSnapshot(keys: [
    "meetingsOnly", "showingEventDetails", "compactMode",
    "hideDeclinedEvents", "sizeMode", "autoReposition", "repositionCorner",
])
```

Add new tests before the closing brace of `CountdownModelTests`:

```swift
// MARK: - Size mode

@Test func sizeModeDefaultsToStandardWhenNothingPersisted() {
    UserDefaults.standard.removeObject(forKey: "sizeMode")
    UserDefaults.standard.removeObject(forKey: "compactMode")
    let model = CountdownModel()
    #expect(model.sizeMode == .standard)
}

@Test func sizeModeMigratesFromLegacyCompactModeTrue() {
    UserDefaults.standard.removeObject(forKey: "sizeMode")
    UserDefaults.standard.set(true, forKey: "compactMode")
    let model = CountdownModel()
    #expect(model.sizeMode == .compact)
}

@Test func sizeModeMigratesFromLegacyCompactModeFalse() {
    UserDefaults.standard.removeObject(forKey: "sizeMode")
    UserDefaults.standard.set(false, forKey: "compactMode")
    let model = CountdownModel()
    #expect(model.sizeMode == .standard)
}

@Test func sizeModePersists() {
    let model = CountdownModel()
    model.sizeMode = .auto
    let model2 = CountdownModel()
    #expect(model2.sizeMode == .auto)
}

@Test func applyEffectiveModeStandard() {
    let model = CountdownModel()
    model.sizeMode = .standard
    model.applyEffectiveMode(hasExternalDisplay: false)
    #expect(model.compactMode == false)
    model.applyEffectiveMode(hasExternalDisplay: true)
    #expect(model.compactMode == false)
}

@Test func applyEffectiveModeCompact() {
    let model = CountdownModel()
    model.sizeMode = .compact
    model.applyEffectiveMode(hasExternalDisplay: false)
    #expect(model.compactMode == true)
    model.applyEffectiveMode(hasExternalDisplay: true)
    #expect(model.compactMode == true)
}

@Test func applyEffectiveModeAutoWithoutExternalUsesCompact() {
    let model = CountdownModel()
    model.sizeMode = .auto
    model.applyEffectiveMode(hasExternalDisplay: false)
    #expect(model.compactMode == true)
}

@Test func applyEffectiveModeAutoWithExternalUsesStandard() {
    let model = CountdownModel()
    model.sizeMode = .auto
    model.applyEffectiveMode(hasExternalDisplay: true)
    #expect(model.compactMode == false)
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

// MARK: - Context menu toggle respects sizeMode

@Test func toggleCompactModeUpdatesSizeMode() {
    let model = CountdownModel()
    model.sizeMode = .auto
    model.applyEffectiveMode(hasExternalDisplay: true)  // compactMode=false
    model.toggleCompactMode()
    #expect(model.sizeMode == .compact)
    #expect(model.compactMode == true)
    model.toggleCompactMode()
    #expect(model.sizeMode == .standard)
    #expect(model.compactMode == false)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -30`
Expected: Compilation errors — `SizeMode`, `ScreenCorner`, `sizeMode`, `autoReposition`, `repositionCorner`, `applyEffectiveMode` don't exist.

**Step 3: Update `CountdownModel.swift`**

Add the enums above the `CountdownModel` class:

```swift
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

Modify `CountdownModel`:

1. Change the `compactMode` property so its `didSet` no longer writes to UserDefaults — it's now effective state, not a persisted preference. Keep it as a public `var` so layout tests that assign it directly continue to compile:

```swift
// Effective state — derived from sizeMode + current display configuration.
// Production code should route changes through sizeMode or applyEffectiveMode;
// tests may set it directly to exercise layout logic.
var compactMode: Bool = false
```

2. Add new persisted properties. The `sizeMode` didSet also updates `compactMode` for fixed modes so settings changes take effect immediately:

```swift
var sizeMode: SizeMode {
    didSet {
        defaults.set(sizeMode.rawValue, forKey: DefaultsKey.sizeMode)
        switch sizeMode {
        case .standard: compactMode = false
        case .compact: compactMode = true
        case .auto: break  // AppDelegate calls applyEffectiveMode via observation
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

3. Update `init` — remove the old `compactMode` load, add migration and new loads:

```swift
init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.meetingsOnly = defaults.bool(forKey: DefaultsKey.meetingsOnly)
    if defaults.object(forKey: DefaultsKey.hideDeclinedEvents) == nil {
        self.hideDeclinedEvents = true
    } else {
        self.hideDeclinedEvents = defaults.bool(forKey: DefaultsKey.hideDeclinedEvents)
    }

    // Migrate: if sizeMode isn't set but legacy compactMode is, derive sizeMode from it.
    let resolvedMode: SizeMode
    if defaults.object(forKey: DefaultsKey.sizeMode) != nil {
        resolvedMode = SizeMode(rawValue: defaults.integer(forKey: DefaultsKey.sizeMode)) ?? .standard
    } else if defaults.object(forKey: DefaultsKey.compactMode) != nil {
        resolvedMode = defaults.bool(forKey: DefaultsKey.compactMode) ? .compact : .standard
    } else {
        resolvedMode = .standard
    }
    self.sizeMode = resolvedMode
    // Persist migrated value so the didSet-free init path still writes it.
    defaults.set(resolvedMode.rawValue, forKey: DefaultsKey.sizeMode)

    self.autoReposition = defaults.bool(forKey: DefaultsKey.autoReposition)
    self.repositionCorner = ScreenCorner(rawValue: defaults.integer(forKey: DefaultsKey.repositionCorner)) ?? .topLeft

    // Set initial compactMode to match non-auto sizeMode. Auto mode is applied
    // by AppDelegate after init once NSScreen is available.
    switch resolvedMode {
    case .standard: self.compactMode = false
    case .compact: self.compactMode = true
    case .auto: self.compactMode = false  // placeholder, replaced on applyEffectiveMode
    }

    if defaults.object(forKey: DefaultsKey.showingEventDetails) == nil {
        self.showingEventDetails = true
    } else {
        self.showingEventDetails = defaults.bool(forKey: DefaultsKey.showingEventDetails)
    }
}
```

4. Add the `applyEffectiveMode` method:

```swift
func applyEffectiveMode(hasExternalDisplay: Bool) {
    let newValue: Bool
    switch sizeMode {
    case .standard: newValue = false
    case .compact: newValue = true
    case .auto: newValue = !hasExternalDisplay
    }
    if compactMode != newValue {
        compactMode = newValue
    }
}
```

5. Update `toggleCompactMode` — it now sets `sizeMode` explicitly (overrides auto):

```swift
func toggleCompactMode() {
    if compactMode {
        sizeMode = .standard
        compactMode = false
    } else {
        sizeMode = .compact
        compactMode = true
    }
}
```

6. Add to `DefaultsKey`:

```swift
static let sizeMode = "sizeMode"
static let autoReposition = "autoReposition"
static let repositionCorner = "repositionCorner"
```

**Step 4: Update legacy tests that rely on the old persistence contract**

Three legacy tests in `CountdownTests/CountdownModelTests.swift` no longer match the new behaviour:

1. **Remove** `compactModePersists` (lines ~561-568). Persistence now lives on `sizeMode`, covered by the new `sizeModePersists` test. A dedicated `compactMode` persistence test would assert a contract that no longer exists.

2. **Update** `compactModeDefaultsToFalse` (lines ~555-559) to also clear the `sizeMode` key so the test genuinely exercises the defaults path:

```swift
@Test func compactModeDefaultsToFalse() {
    UserDefaults.standard.removeObject(forKey: "compactMode")
    UserDefaults.standard.removeObject(forKey: "sizeMode")
    let model = CountdownModel()
    #expect(model.compactMode == false)
}
```

3. **Update** `toggleCompactMode` (lines ~570-577) to assert that sizeMode moves in lockstep:

```swift
@Test func toggleCompactMode() {
    let model = CountdownModel()
    model.sizeMode = .standard  // ensures compactMode == false
    model.toggleCompactMode()
    #expect(model.compactMode == true)
    #expect(model.sizeMode == .compact)
    model.toggleCompactMode()
    #expect(model.compactMode == false)
    #expect(model.sizeMode == .standard)
}
```

The new `toggleCompactModeUpdatesSizeMode` test added in Step 1 covers the auto → explicit transition, so the two tests are complementary.

The `compactModeChangesAreObservable` test (lines ~579-591) still works without modification — compactMode is still `@Observable` via the class, the toggle still updates it, and the test only checks that observation fires.

The `OverlayLayoutStateModelTests` suite in `CountdownTests/OverlayPositionTests.swift` (lines ~471-515) sets `model.compactMode = true` directly to exercise layout state construction. Leave those tests alone — compactMode remains a settable `var`, and the tests are about layout logic, not persistence. No changes needed.

**Step 5: Run tests to verify they pass**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -30`
Expected: All tests pass, including the updated legacy tests and the existing `compactModeChangesAreObservable` test.

**Step 6: Commit**

```
feat: SizeMode with migration from legacy compactMode key
```

---

### Task 3: Refactor OverlayFramePlacement to be anchor-aware

**Files:**
- Modify: `Countdown/OverlayPanel.swift`
- Modify: `CountdownTests/OverlayPositionTests.swift`

**Why this matters:** Current `OverlayFramePlacement` pins `x` (left edge) and `topEdge`. When the user enables auto-reposition with the top-right corner, a resize (compact→standard) would leave the left edge pinned — the panel's right edge would drift. Must support all four anchor corners so the pinned corner stays put across resizes.

**Step 1: Write failing tests for anchor-aware placement**

There is already an `OverlayFramePlacementTests` suite in `CountdownTests/OverlayPositionTests.swift` (around line 172). Add the new tests **inside** that existing suite — do not create a second suite with the same name.

```swift
// Add inside the existing OverlayFramePlacementTests suite:

    @Test func topLeftAnchorKeepsTopLeftPinnedOnResize() {
        var placement = OverlayFramePlacement(
            initialFrame: CGRect(x: 100, y: 500, width: 200, height: 120),
            restoredOrigin: nil,
            anchor: .topLeft
        )
        // Record so the placement knows the current frame's edges
        placement.record(frame: CGRect(x: 100, y: 500, width: 200, height: 120))

        let frame = placement.frame(for: CGSize(width: 400, height: 36))
        #expect(frame.minX == 100)
        #expect(frame.maxY == 620)  // original topEdge (500 + 120)
    }

    @Test func topRightAnchorKeepsTopRightPinnedOnResize() {
        var placement = OverlayFramePlacement(
            initialFrame: CGRect(x: 100, y: 500, width: 200, height: 120),
            restoredOrigin: nil,
            anchor: .topRight
        )
        placement.record(frame: CGRect(x: 100, y: 500, width: 200, height: 120))
        // Original maxX = 300, topEdge = 620

        let frame = placement.frame(for: CGSize(width: 400, height: 36))
        #expect(frame.maxX == 300)  // right edge stays pinned
        #expect(frame.maxY == 620)
    }

    @Test func bottomLeftAnchorKeepsBottomLeftPinnedOnResize() {
        var placement = OverlayFramePlacement(
            initialFrame: CGRect(x: 100, y: 500, width: 200, height: 120),
            restoredOrigin: nil,
            anchor: .bottomLeft
        )
        placement.record(frame: CGRect(x: 100, y: 500, width: 200, height: 120))

        let frame = placement.frame(for: CGSize(width: 400, height: 36))
        #expect(frame.minX == 100)
        #expect(frame.minY == 500)
    }

    @Test func bottomRightAnchorKeepsBottomRightPinnedOnResize() {
        var placement = OverlayFramePlacement(
            initialFrame: CGRect(x: 100, y: 500, width: 200, height: 120),
            restoredOrigin: nil,
            anchor: .bottomRight
        )
        placement.record(frame: CGRect(x: 100, y: 500, width: 200, height: 120))

        let frame = placement.frame(for: CGSize(width: 400, height: 36))
        #expect(frame.maxX == 300)
        #expect(frame.minY == 500)
    }

    @Test func restoredOriginOverridesAnchorFirstTime() {
        var placement = OverlayFramePlacement(
            initialFrame: CGRect(x: 0, y: 0, width: 200, height: 120),
            restoredOrigin: CGPoint(x: 50, y: 60),
            anchor: .topLeft
        )
        let frame = placement.frame(for: CGSize(width: 200, height: 120))
        #expect(frame.minX == 50)
        #expect(frame.minY == 60)
    }
```

(No trailing `}` — the closing brace of the existing `OverlayFramePlacementTests` struct already exists at the end of the file.)

Note: the existing tests `restoredOriginIsPreservedOnFirstResize` and `liveFrameWithoutRestoredOriginKeepsCurrentTopEdge` (lines 174-197 of the current test file) call `OverlayFramePlacement(initialFrame:restoredOrigin:)` without an anchor argument. Since the new initialiser gives `anchor` a default value of `.topLeft`, those existing tests continue to compile and pass without modification.

Also add tests for `cornerOrigin` (pure function — also new):

```swift
// MARK: - Corner positioning

@Test func cornerOriginTopLeft() {
    let origin = OverlayPosition.cornerOrigin(
        corner: .topLeft,
        visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        panelSize: CGSize(width: 200, height: 120)
    )
    #expect(origin.x == 20)
    #expect(origin.y == 1080 - 120 - 20)
}

@Test func cornerOriginTopRight() {
    let origin = OverlayPosition.cornerOrigin(
        corner: .topRight,
        visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        panelSize: CGSize(width: 200, height: 120)
    )
    #expect(origin.x == 1920 - 200 - 20)
    #expect(origin.y == 1080 - 120 - 20)
}

@Test func cornerOriginBottomLeft() {
    let origin = OverlayPosition.cornerOrigin(
        corner: .bottomLeft,
        visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        panelSize: CGSize(width: 200, height: 120)
    )
    #expect(origin.x == 20)
    #expect(origin.y == 20)
}

@Test func cornerOriginBottomRight() {
    let origin = OverlayPosition.cornerOrigin(
        corner: .bottomRight,
        visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        panelSize: CGSize(width: 200, height: 120)
    )
    #expect(origin.x == 1920 - 200 - 20)
    #expect(origin.y == 20)
}

@Test func cornerOriginRespectsScreenOffset() {
    let origin = OverlayPosition.cornerOrigin(
        corner: .topLeft,
        visibleFrame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
        panelSize: CGSize(width: 200, height: 120)
    )
    #expect(origin.x == 1920 + 20)
    #expect(origin.y == 1440 - 120 - 20)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -30`
Expected: Compilation errors on anchor parameter, `cornerOrigin`, etc.

**Step 3: Refactor `OverlayFramePlacement`**

In `Countdown/OverlayPanel.swift`, replace the existing `OverlayFramePlacement` struct:

```swift
struct OverlayFramePlacement {
    private var anchor: ScreenCorner
    private var anchorX: CGFloat  // left edge for left anchors, right edge for right anchors
    private var anchorY: CGFloat  // top edge for top anchors, bottom edge for bottom anchors
    private var restoredOrigin: CGPoint?

    init(initialFrame: CGRect, restoredOrigin: CGPoint?, anchor: ScreenCorner = .topLeft) {
        self.anchor = anchor
        self.anchorX = Self.referenceX(for: initialFrame, anchor: anchor)
        self.anchorY = Self.referenceY(for: initialFrame, anchor: anchor)
        self.restoredOrigin = restoredOrigin
    }

    mutating func setAnchor(_ newAnchor: ScreenCorner, currentFrame: CGRect) {
        self.anchor = newAnchor
        self.anchorX = Self.referenceX(for: currentFrame, anchor: newAnchor)
        self.anchorY = Self.referenceY(for: currentFrame, anchor: newAnchor)
        self.restoredOrigin = nil
    }

    mutating func frame(for size: CGSize) -> CGRect {
        if let restoredOrigin {
            self.restoredOrigin = nil
            let newFrame = CGRect(origin: restoredOrigin, size: size)
            self.anchorX = Self.referenceX(for: newFrame, anchor: anchor)
            self.anchorY = Self.referenceY(for: newFrame, anchor: anchor)
            return newFrame
        }

        let originX: CGFloat
        let originY: CGFloat
        switch anchor {
        case .topLeft:
            originX = anchorX
            originY = anchorY - size.height
        case .topRight:
            originX = anchorX - size.width
            originY = anchorY - size.height
        case .bottomLeft:
            originX = anchorX
            originY = anchorY
        case .bottomRight:
            originX = anchorX - size.width
            originY = anchorY
        }
        return CGRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    mutating func record(frame: CGRect) {
        anchorX = Self.referenceX(for: frame, anchor: anchor)
        anchorY = Self.referenceY(for: frame, anchor: anchor)
        restoredOrigin = nil
    }

    private static func referenceX(for frame: CGRect, anchor: ScreenCorner) -> CGFloat {
        switch anchor {
        case .topLeft, .bottomLeft: return frame.minX
        case .topRight, .bottomRight: return frame.maxX
        }
    }

    private static func referenceY(for frame: CGRect, anchor: ScreenCorner) -> CGFloat {
        switch anchor {
        case .topLeft, .topRight: return frame.maxY
        case .bottomLeft, .bottomRight: return frame.minY
        }
    }
}
```

**Step 4: Add `cornerOrigin` to `OverlayPosition` and `positionInCorner` to `OverlayPanel`**

Add to `OverlayPosition` enum:

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

Keep existing `positionTopLeft()` — just delegate:

```swift
func positionTopLeft() {
    positionInCorner(.topLeft)
}
```

**Step 5: Run tests to verify they pass**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -30`
Expected: All tests pass. The existing `OverlayFramePlacement` usage in AppDelegate still compiles because the `init` now has a default `anchor` parameter.

**Step 6: Commit**

```
refactor: anchor-aware OverlayFramePlacement with corner support
```

---

### Task 4: Wire up AppDelegate — launch, screen change, and observation

**Files:**
- Modify: `Countdown/AppDelegate.swift`

**Why this matters:** The model can't apply auto mode on its own — it needs to know about NSScreen, and SwiftUI settings changes need to immediately take effect. AppDelegate observes `sizeMode`/`autoReposition`/`repositionCorner` and pipes in screen info. Precedence rule for launch: if `autoReposition` is on, corner placement overrides saved position.

**Step 1: Update `applicationDidFinishLaunching` to apply auto mode and initial positioning**

The current launch sequence in `AppDelegate.swift` (lines 75-78) is:

```swift
self.overlayPanel = panel
panel.ensureOnScreen()
let restoredOrigin = OverlayPosition.restore() != nil ? panel.frame.origin : nil
panelPlacement = OverlayFramePlacement(initialFrame: panel.frame, restoredOrigin: restoredOrigin)
```

The new auto-mode and corner-reposition logic must be inserted **after** `panelPlacement` is initialised on line 78 — otherwise the `OverlayFramePlacement(...)` constructor would overwrite any anchor we set. Insert the new block immediately after line 78, before the `NotificationCenter.default.addObserver(...)` call:

```swift
// Apply the effective compact mode based on current display configuration.
// This may update `compactMode`, which the observer will pick up on the next tick.
calendarManager.model.applyEffectiveMode(
    hasExternalDisplay: DisplayDetection.hasExternalDisplay()
)

// Initialise change-tracking state for the observation handler.
lastAutoReposition = calendarManager.model.autoReposition
lastRepositionCorner = calendarManager.model.repositionCorner

// If auto-reposition is on, corner placement takes precedence over any
// saved manual position. Snap the panel and re-anchor the placement so
// subsequent content-size changes pin to the correct corner.
if calendarManager.model.autoReposition {
    panel.positionInCorner(calendarManager.model.repositionCorner)
    panelPlacement.setAnchor(
        calendarManager.model.repositionCorner,
        currentFrame: panel.frame
    )
}
```

Do NOT move or duplicate the existing lines 75-78. The block above goes between line 78 and the notification observer registration (line 80).

**Step 2: Update `screenDidChange` handler**

Replace the existing `screenDidChange` method:

```swift
@objc private func screenDidChange(_ notification: Notification) {
    guard let panel = overlayPanel else { return }
    let model = calendarManager.model

    // Auto mode may need to switch based on new display configuration.
    model.applyEffectiveMode(hasExternalDisplay: DisplayDetection.hasExternalDisplay())

    if model.autoReposition {
        panel.positionInCorner(model.repositionCorner)
        panelPlacement.setAnchor(model.repositionCorner, currentFrame: panel.frame)
    } else {
        panel.ensureOnScreen()
        panelPlacement.record(frame: panel.frame)
    }
}
```

**Step 3: Extend `observeOverlayState` to react to new preferences**

The observation needs to catch three cases:
- `sizeMode` changed → recompute effective mode → may trigger `compactMode` change (which is already tracked and triggers updatePanel)
- `autoReposition` changed → if toggled ON, snap to corner and re-anchor placement; if toggled OFF, re-anchor placement to topLeft at current frame (so subsequent content resizes pin top-left naturally, matching the pre-auto behaviour)
- `repositionCorner` changed (while `autoReposition` is on) → snap to new corner, re-anchor

`handleModelChange` is called for every tracked property change, so blindly re-anchoring on every tick would be wasteful. Track `lastAutoReposition` and `lastRepositionCorner` as private AppDelegate properties and only re-anchor when those values actually change.

Add to `AppDelegate`:

```swift
private var lastAutoReposition: Bool = false
private var lastRepositionCorner: ScreenCorner = .topLeft
```

These are already initialised in Step 1's launch-sequence block.

Update `observeOverlayState` to track the new properties and dispatch to `handleModelChange`:

```swift
private func observeOverlayState() {
    withObservationTracking {
        _ = calendarManager.isSignedIn
        _ = calendarManager.model.shouldShowOverlay
        _ = calendarManager.model.showingEventDetails
        _ = calendarManager.model.isIdle
        _ = calendarManager.model.isLoading
        _ = calendarManager.model.compactMode
        _ = calendarManager.model.sizeMode
        _ = calendarManager.model.autoReposition
        _ = calendarManager.model.repositionCorner
    } onChange: { [weak self] in
        Task { @MainActor [weak self] in
            self?.handleModelChange()
            self?.observeOverlayState()
        }
    }
}
```

Add the guarded `handleModelChange`:

```swift
@MainActor
private func handleModelChange() {
    let model = calendarManager.model
    guard let panel = overlayPanel else {
        updatePanel()
        return
    }

    // Keep effective compactMode in sync with sizeMode + display state.
    model.applyEffectiveMode(hasExternalDisplay: DisplayDetection.hasExternalDisplay())

    let autoRepositionChanged = model.autoReposition != lastAutoReposition
    let cornerChanged = model.repositionCorner != lastRepositionCorner

    if autoRepositionChanged || (model.autoReposition && cornerChanged) {
        if model.autoReposition {
            panel.positionInCorner(model.repositionCorner)
            panelPlacement.setAnchor(model.repositionCorner, currentFrame: panel.frame)
        } else {
            // Auto-reposition just turned off — return to default top-left anchoring
            // using wherever the panel currently is as the reference point.
            panelPlacement.setAnchor(.topLeft, currentFrame: panel.frame)
        }
    }

    lastAutoReposition = model.autoReposition
    lastRepositionCorner = model.repositionCorner

    updatePanel()
}
```

**Step 4: Build and run tests**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build 2>&1 | tail -20`
Expected: Build succeeds.

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -30`
Expected: All tests pass.

**Step 5: Commit**

```
feat: apply effective display mode on launch, screen change, and settings change
```

---

### Task 5: Settings UI — three-way picker, help popover, reposition controls

**Files:**
- Modify: `Countdown/SettingsView.swift`

**Step 1: Remove `compactModeBinding`, add new bindings**

Remove the `compactModeBinding` computed property (lines 102-107). Add:

```swift
private var sizeModeBinding: Binding<SizeMode> {
    Binding(
        get: { manager.model.sizeMode },
        set: { manager.model.sizeMode = $0 }
    )
}

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

**Step 2: Replace the "Circle size" section in `filterSection`**

Replace lines 193-202 (the existing "Circle size" label + picker):

```swift
HStack(spacing: 4) {
    Text("Circle size")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    AutoModeHelpButton()
    Spacer()
}
.padding(.top, 4)

Picker("", selection: sizeModeBinding) {
    Text("Standard").tag(SizeMode.standard)
    Text("Compact").tag(SizeMode.compact)
    Text("Auto").tag(SizeMode.auto)
}
.pickerStyle(.segmented)

Toggle("Auto-reposition on display change", isOn: autoRepositionBinding)
    .toggleStyle(.switch)
    .padding(.top, 4)

if manager.model.autoReposition {
    Picker("", selection: repositionCornerBinding) {
        Text("Top L").tag(ScreenCorner.topLeft)
        Text("Top R").tag(ScreenCorner.topRight)
        Text("Bot L").tag(ScreenCorner.bottomLeft)
        Text("Bot R").tag(ScreenCorner.bottomRight)
    }
    .pickerStyle(.segmented)
}
```

(Labels are short because the settings panel is 280px wide — four segments need to fit.)

**Step 3: Add the help popover view at the bottom of SettingsView.swift**

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
        .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
            Text("Auto uses the compact size on your built-in display alone, and the standard size when an external display is connected.")
                .font(.caption)
                .frame(width: 220)
                .padding(10)
        }
    }
}
```

**Step 4: Build and run tests**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build 2>&1 | tail -20`
Expected: Build succeeds.

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -30`
Expected: All tests pass.

**Step 5: Commit**

```
feat: settings UI for auto size mode and corner reposition
```

---

### Task 6: Final integration verification

**Step 1: Run full test suite**

Run: `xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40`
Expected: All tests pass.

**Step 2: Build the app**

Run: `xcodebuild -project Countdown.xcodeproj -scheme Countdown build 2>&1 | tail -20`
Expected: Build succeeds.

**Step 3: Manual verification checklist**

Run the app and verify each scenario (document results inline):

- [ ] Fresh install — sizeMode defaults to Standard, autoReposition off
- [ ] Existing install (simulate by setting only `compactMode=true` in UserDefaults before launch) — sizeMode migrates to `.compact`
- [ ] Select Standard → panel uses standard layout immediately
- [ ] Select Compact → panel uses compact layout immediately
- [ ] Select Auto on laptop alone → compact layout
- [ ] Select Auto with external display plugged in → standard layout
- [ ] Disconnect external display while Auto is on → layout switches to compact
- [ ] Reconnect external → switches back to standard
- [ ] Enable auto-reposition with top-left → panel snaps to top-left of current screen
- [ ] Change corner to top-right → panel snaps to top-right
- [ ] Resize happens (compact ↔ standard) while anchored top-right → right edge stays pinned
- [ ] Resize happens while anchored bottom-right → bottom-right stays pinned
- [ ] Disable auto-reposition → panel stays where it is, future resizes pin top-left as before
- [ ] Drag the panel while auto-reposition is on → drag works; next display change snaps it back to corner

**Step 4: Commit any cleanup**

If no changes were needed, no commit. Otherwise commit with a descriptive message.
