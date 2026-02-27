// ABOUTME: Generates PKCE code verifier and challenge per RFC 7636.
// ABOUTME: Used during Google OAuth to secure the authorisation code exchange.

import CryptoKit
import Foundation
import Security

struct PKCE {
    let codeVerifier: String
    let codeChallenge: String

    init() throws {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw PKCEError.failedToGenerateRandomBytes
        }

        self.codeVerifier = Data(bytes).base64URLEncodedString()
        let data = codeVerifier.data(using: .ascii)!
        let hash = SHA256.hash(data: data)
        self.codeChallenge = Data(hash).base64URLEncodedString()
    }
}

enum PKCEError: Error {
    case failedToGenerateRandomBytes
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
