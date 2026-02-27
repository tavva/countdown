// ABOUTME: Tests for overlay panel position persistence.
// ABOUTME: Verifies saving, restoring, and clearing saved positions via UserDefaults.

import Testing
import Foundation
@testable import Countdown

@Suite("OverlayPosition", .serialized)
struct OverlayPositionTests {
    let defaults = UserDefaults.standard
    let key = "overlayPosition"

    init() {
        defaults.removeObject(forKey: key)
    }

    @Test func restoreReturnsNilWhenNoSavedPosition() {
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
}
