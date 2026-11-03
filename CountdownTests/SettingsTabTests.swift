// ABOUTME: Tests for remembering the selected settings tab.
// ABOUTME: Covers the default when nothing or something invalid is stored, and round-tripping.

import Testing
import Foundation
@testable import Countdown

@Suite("SettingsTab", .serialized)
struct SettingsTabTests {
    private let _snapshot = DefaultsSnapshot(keys: ["settingsTab"])

    @Test func restoreDefaultsToCircleWhenNothingStored() {
        #expect(SettingsTab.restore() == .circle)
    }

    @Test func restoreDefaultsToCircleWhenStoredValueIsNotATab() {
        UserDefaults.app.set("display", forKey: "settingsTab")
        #expect(SettingsTab.restore() == .circle)
    }

    @Test func restoreDefaultsToCircleWhenStoredValueIsNotAString() {
        UserDefaults.app.set(2, forKey: "settingsTab")
        #expect(SettingsTab.restore() == .circle)
    }

    @Test(arguments: SettingsTab.allCases)
    func saveAndRestoreRoundTrips(tab: SettingsTab) {
        tab.save()
        #expect(SettingsTab.restore() == tab)
    }
}
