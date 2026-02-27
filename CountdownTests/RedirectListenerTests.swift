// ABOUTME: Tests that the OAuth redirect listener validates the state parameter.
// ABOUTME: Verifies CSRF protection by rejecting redirects with mismatched state values.

import Foundation
import Testing
@testable import Countdown

@Suite("RedirectListener")
struct RedirectListenerTests {
    @Test func rejectsRedirectWithMismatchedState() throws {
        let components = URLComponents(string: "http://localhost/?code=auth-code&state=wrong-state")
        #expect(throws: GoogleAuthError.stateMismatch) {
            try RedirectListener.extractCode(from: components, expectedState: "correct-state")
        }
    }

    @Test func acceptsRedirectWithMatchingState() throws {
        let components = URLComponents(string: "http://localhost/?code=auth-code&state=expected-state")
        let code = try RedirectListener.extractCode(from: components, expectedState: "expected-state")
        #expect(code == "auth-code")
    }

    @Test func rejectsRedirectWithMissingState() throws {
        let components = URLComponents(string: "http://localhost/?code=auth-code")
        #expect(throws: GoogleAuthError.stateMismatch) {
            try RedirectListener.extractCode(from: components, expectedState: "some-state")
        }
    }
}
