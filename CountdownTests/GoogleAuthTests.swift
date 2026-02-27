// ABOUTME: Tests for Google OAuth URL construction and token response parsing.
// ABOUTME: Uses MockURLProtocol to test token exchange and refresh without network.

import Testing
import Foundation
@testable import Countdown

@Suite("GoogleAuth", .serialized)
struct GoogleAuthTests {
    let session = MockURLProtocol.makeSession()

    @Test func authURLContainsRequiredParameters() throws {
        let pkce = try PKCE()
        let url = GoogleAuth.buildAuthURL(
            clientID: "test-client-id",
            redirectPort: 8080,
            pkce: pkce,
            state: "test-state"
        )

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let params = Dictionary(
            uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) }
        )

        #expect(params["client_id"] == "test-client-id")
        #expect(params["redirect_uri"] == "http://127.0.0.1:8080")
        #expect(params["response_type"] == "code")
        #expect(params["scope"] == "https://www.googleapis.com/auth/calendar.readonly")
        #expect(params["code_challenge"] == pkce.codeChallenge)
        #expect(params["code_challenge_method"] == "S256")
        #expect(params["access_type"] == "offline")
        #expect(params["prompt"] == "consent")
        #expect(params["state"] == "test-state")
    }

    @Test func tokenExchangeDecodesResponse() async throws {
        await MockURLProtocol.requestHandler.set { request in
            let body = """
            {
                "access_token": "ya29.test",
                "expires_in": 3600,
                "refresh_token": "1//test-refresh",
                "token_type": "Bearer",
                "scope": "https://www.googleapis.com/auth/calendar.readonly"
            }
            """
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(body.utf8))
        }

        let tokens = try await GoogleAuth.exchangeCode(
            "test-code",
            codeVerifier: "test-verifier",
            clientID: "id",
            clientSecret: "secret",
            redirectPort: 8080,
            session: session
        )

        #expect(tokens.accessToken == "ya29.test")
        #expect(tokens.refreshToken == "1//test-refresh")
        #expect(tokens.expiresIn == 3600)
    }

    @Test func tokenRefreshDecodesResponse() async throws {
        await MockURLProtocol.requestHandler.set { request in
            let body = """
            {
                "access_token": "ya29.refreshed",
                "expires_in": 3600,
                "token_type": "Bearer"
            }
            """
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(body.utf8))
        }

        let token = try await GoogleAuth.refreshAccessToken(
            refreshToken: "1//refresh",
            clientID: "id",
            clientSecret: "secret",
            session: session
        )

        #expect(token.accessToken == "ya29.refreshed")
    }
}
