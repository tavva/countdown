// ABOUTME: Tests for the session the app uses for Google API calls.
// ABOUTME: Checks it keeps no response cache, which would grow on every poll.

import Testing
import Foundation
@testable import Countdown

@Suite("URLSession.uncached")
struct URLSessionUncachedTests {
    @Test func hasNoResponseCache() {
        let configuration = URLSession.uncached.configuration
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }
}
