// ABOUTME: Chooses which UserDefaults domain the app's settings are read from and written to.
// ABOUTME: Tests and preview builds get a scratch domain instead of the installed app's.

import Foundation

extension UserDefaults {
    /// Where the app stores its settings.
    ///
    /// The test bundle is hosted by the app and preview builds run from the same
    /// bundle identifier, so both would otherwise read and overwrite the settings
    /// of the copy of Countdown the user actually runs. They get a scratch domain.
    nonisolated(unsafe) static let app: UserDefaults = {
        let isTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let isPreview = CommandLine.arguments.contains("--preview-settings")
            || CommandLine.arguments.contains("--preview-overlay")
        guard isTest || isPreview else { return .standard }
        return UserDefaults(suiteName: "com.countdown.scratch") ?? .standard
    }()
}
