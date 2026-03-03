// ABOUTME: Tests for overlay panel position persistence and screen visibility.
// ABOUTME: Verifies saving, restoring, clearing, and off-screen detection.

import Testing
import Foundation
@testable import Countdown

@Suite("OverlayPosition", .serialized)
struct OverlayPositionTests {
    private let _snapshot = DefaultsSnapshot(keys: ["overlayPosition"])

    @Test func restoreReturnsNilWhenNoSavedPosition() {
        UserDefaults.standard.removeObject(forKey: "overlayPosition")
        #expect(OverlayPosition.restore() == nil)
    }

    @Test func saveAndRestoreRoundTrips() {
        let origin = CGPoint(x: 123.5, y: 456.0)
        OverlayPosition.save(origin)

        let restored = OverlayPosition.restore()
        #expect(restored != nil)
        #expect(restored!.x == 123.5)
        #expect(restored!.y == 456.0)
    }

    @Test func clearRemovesSavedPosition() {
        OverlayPosition.save(CGPoint(x: 10, y: 20))
        OverlayPosition.clear()
        #expect(OverlayPosition.restore() == nil)
    }

    // MARK: - Screen visibility

    @Test func positionInsideSingleScreenIsVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        #expect(OverlayPosition.isVisible(origin: CGPoint(x: 100, y: 100), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionOffRightEdgeIsNotVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        #expect(!OverlayPosition.isVisible(origin: CGPoint(x: 2000, y: 100), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionOnSecondScreenIsVisible() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 2560, height: 1440),
        ]
        #expect(OverlayPosition.isVisible(origin: CGPoint(x: 2000, y: 100), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionBelowAllScreensIsNotVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        #expect(!OverlayPosition.isVisible(origin: CGPoint(x: 100, y: -200), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionWithNoScreensIsNotVisible() {
        let screens: [CGRect] = []
        #expect(!OverlayPosition.isVisible(origin: CGPoint(x: 100, y: 100), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionPartiallyVisibleIsVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        // Panel at x: 1800 — only 120px of 200px width visible, but centre is on screen
        #expect(OverlayPosition.isVisible(origin: CGPoint(x: 1800, y: 500), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }

    @Test func positionWithOnlyCentreOffScreenIsNotVisible() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        // Panel centre at x: 2000 — off screen
        #expect(!OverlayPosition.isVisible(origin: CGPoint(x: 1900, y: 500), panelSize: CGSize(width: 200, height: 120), screenFrames: screens))
    }
}

@Suite("OverlayLayout")
struct OverlayLayoutTests {
    @Test func roundsMeasuredHeightUpToWholePoints() {
        #expect(OverlayLayout.normalizedContentHeight(189.01) == 190)
        #expect(OverlayLayout.normalizedContentHeight(190.0) == 190)
    }

    @Test func ignoresJitterThatRoundsToCurrentHeight() {
        #expect(!OverlayLayout.shouldApplyMeasuredHeight(current: 190, measured: 189.1))
        #expect(!OverlayLayout.shouldApplyMeasuredHeight(current: 190, measured: 190.0))
    }

    @Test func appliesHeightWhenRoundedValueChanges() {
        #expect(OverlayLayout.shouldApplyMeasuredHeight(current: 190, measured: 190.2))
        #expect(OverlayLayout.shouldApplyMeasuredHeight(current: 190, measured: 191.0))
    }
}
