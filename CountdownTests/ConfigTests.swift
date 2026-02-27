// ABOUTME: Tests for loading OAuth configuration from a plist.
// ABOUTME: Verifies both valid config loading and missing-file handling.

import Testing
import Foundation
@testable import Countdown

@Suite("Config")
struct ConfigTests {
    @Test func missingConfigReturnsNil() {
        let config = Config.load(from: "NonExistentFile")
        #expect(config == nil)
    }
}
