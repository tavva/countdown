// ABOUTME: Tests for PKCE code verifier and challenge generation.
// ABOUTME: Validates RFC 7636 compliance: length, character set, challenge derivation.

import Testing
import Foundation
import CryptoKit
@testable import Countdown

@Suite("PKCE")
struct PKCETests {
    @Test func verifierIsBase64URL() throws {
        let pkce = try PKCE()
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        #expect(pkce.codeVerifier.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    @Test func verifierHasMinimumLength() throws {
        let pkce = try PKCE()
        #expect(pkce.codeVerifier.count >= 43)
    }

    @Test func challengeMatchesVerifier() throws {
        let pkce = try PKCE()
        let data = pkce.codeVerifier.data(using: .ascii)!
        let hash = SHA256.hash(data: data)
        let expected = Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        #expect(pkce.codeChallenge == expected)
    }

    @Test func eachGenerationIsUnique() throws {
        let a = try PKCE()
        let b = try PKCE()
        #expect(a.codeVerifier != b.codeVerifier)
    }
}
