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
