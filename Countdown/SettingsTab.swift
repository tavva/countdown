// ABOUTME: The tabs of the settings pop-up and which one was last selected.
// ABOUTME: Stores the selection in UserDefaults.app so the pop-up reopens on the same tab.

import Foundation

enum SettingsTab: String, CaseIterable {
    case circle
    case events
    case calendars
    case general

    private static let key = "settingsTab"

    /// The last selected tab, or the Circle tab when none is stored or the
    /// stored value doesn't name a tab.
    static func restore(from defaults: UserDefaults = .app) -> SettingsTab {
        defaults.string(forKey: key).flatMap(SettingsTab.init(rawValue:)) ?? .circle
    }

    func save(to defaults: UserDefaults = .app) {
        defaults.set(rawValue, forKey: Self.key)
    }
}
