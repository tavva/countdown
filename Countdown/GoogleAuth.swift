// ABOUTME: Handles the full Google OAuth 2.0 flow: auth URL, token exchange, refresh, revocation.
// ABOUTME: Opens the system browser for sign-in and listens on localhost for the redirect.

import AppKit
import CryptoKit
import Foundation
import Network

enum GoogleAuthError: Error {
    case exchangeFailed(Int, Data)
    case refreshFailed(Int, Data)
    case revocationFailed(Int)
    case missingCode
    case listenerFailed
}

struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

struct RefreshedToken: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

enum GoogleAuth {
    private static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    private static let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke")!

    static func buildAuthURL(
        clientID: String,
        redirectPort: UInt16,
        pkce: PKCE,
        state: String
    ) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "http://127.0.0.1:\(redirectPort)"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/calendar.readonly"),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        return components.url!
    }

    static func exchangeCode(
        _ code: String,
        codeVerifier: String,
        clientID: String,
        clientSecret: String,
        redirectPort: UInt16,
        session: URLSession = .shared
    ) async throws -> TokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode([
            ("code", code),
            ("client_id", clientID),
            ("client_secret", clientSecret),
            ("redirect_uri", "http://127.0.0.1:\(redirectPort)"),
            ("grant_type", "authorization_code"),
            ("code_verifier", codeVerifier),
        ])

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw GoogleAuthError.exchangeFailed(http.statusCode, data)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    static func refreshAccessToken(
        refreshToken: String,
        clientID: String,
        clientSecret: String,
        session: URLSession = .shared
    ) async throws -> RefreshedToken {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode([
            ("refresh_token", refreshToken),
            ("client_id", clientID),
            ("client_secret", clientSecret),
            ("grant_type", "refresh_token"),
        ])

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw GoogleAuthError.refreshFailed(http.statusCode, data)
        }
        return try JSONDecoder().decode(RefreshedToken.self, from: data)
    }

    static func revokeToken(_ token: String, session: URLSession = .shared) async throws {
        var request = URLRequest(url: revokeURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "token=\(token)".data(using: .utf8)

        let (_, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 || http.statusCode == 400 else {
            throw GoogleAuthError.revocationFailed(http.statusCode)
        }
    }

    /// Start a local HTTP listener and initiate browser-based OAuth
    static func signIn(
        clientID: String,
        clientSecret: String
    ) async throws -> TokenResponse {
        let pkce = try PKCE()
        let state = UUID().uuidString

        let listener = try RedirectListener()
        let port = listener.port

        let authURL = buildAuthURL(
            clientID: clientID,
            redirectPort: port,
            pkce: pkce,
            state: state
        )

        NSWorkspace.shared.open(authURL)

        let code = try await listener.waitForCode()

        return try await exchangeCode(
            code,
            codeVerifier: pkce.codeVerifier,
            clientID: clientID,
            clientSecret: clientSecret,
            redirectPort: port
        )
    }

    private static func formEncode(_ params: [(String, String)]) -> Data {
        params
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
            .data(using: .utf8)!
    }
}
