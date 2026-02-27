# Countdown Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that shows a floating countdown circle for upcoming Google Calendar events.

**Architecture:** SwiftUI menu bar app (no Dock icon) with an `NSPanel` overlay. Google Calendar integration via OAuth 2.0 with PKCE, tokens in Keychain. All native — no third-party dependencies.

**Tech Stack:** Swift 6, SwiftUI, AppKit (NSPanel), Security framework (Keychain), CryptoKit (PKCE), Network framework (redirect listener), URLSession. Minimum deployment: macOS 14 (Sonoma). Testing: Swift Testing framework.

---

### Task 1: Xcode Project Scaffolding

Create the Xcode project and verify it builds and runs as a menu bar app with no Dock icon.

**Files:**
- Create: `Countdown.xcodeproj` (via `xcodebuild` or manual)
- Create: `Countdown/CountdownApp.swift`
- Create: `Countdown/AppDelegate.swift`
- Create: `Countdown/Info.plist`

**Step 1: Create the Xcode project**

Use Xcode CLI to create the project structure. Since we can't invoke Xcode GUI, create files manually:

```
Countdown/
├── Countdown.xcodeproj/
├── Countdown/
│   ├── CountdownApp.swift
│   ├── AppDelegate.swift
│   └── Info.plist
└── CountdownTests/
    └── CountdownTests.swift
```

Create `Countdown/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

Create `Countdown/CountdownApp.swift`:
```swift
// ABOUTME: App entry point for the meeting countdown menu bar app.
// ABOUTME: Configures MenuBarExtra with .window style and wires up AppDelegate.

import SwiftUI

@main
struct CountdownApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            Text("Countdown")
                .frame(width: 280, height: 200)
                .padding()
        } label: {
            Image(systemName: "circle.fill")
                .foregroundStyle(.gray)
        }
        .menuBarExtraStyle(.window)
    }
}
```

Create `Countdown/AppDelegate.swift`:
```swift
// ABOUTME: Manages app activation policy to suppress Dock icon.
// ABOUTME: Owns the floating overlay panel lifecycle.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

**Step 2: Create the Xcode project file**

Since we're building from CLI, use a `Package.swift` initially to verify compilation, then generate the xcodeproj. Actually — the simplest approach is to create the project via `swift package init` and use SPM throughout, embedding Info.plist via linker flags. But given the research showed this is fiddly for GUI apps, we should create a proper xcodeproj.

The pragmatic approach: create the project using `xcodebuild` indirectly — write a script that generates the `.xcodeproj` using the `XcodeGen` tool (install via brew), or create it by hand using a minimal `project.yml`.

Install XcodeGen and generate:

```bash
brew install xcodegen
```

Create `project.yml`:
```yaml
name: Countdown
options:
  deploymentTarget:
    macOS: "14.0"
  bundleIdPrefix: com.countdown
settings:
  SWIFT_VERSION: "6.0"
targets:
  Countdown:
    type: application
    platform: macOS
    sources:
      - Countdown
    info:
      path: Countdown/Info.plist
    settings:
      INFOPLIST_FILE: Countdown/Info.plist
      PRODUCT_BUNDLE_IDENTIFIER: com.countdown.app
      PRODUCT_NAME: Countdown
    entitlements:
      path: Countdown/Countdown.entitlements
      properties:
        com.apple.security.network.client: true
        com.apple.security.network.server: true
  CountdownTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - CountdownTests
    dependencies:
      - target: Countdown
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.countdown.tests
```

Create `Countdown/Countdown.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

```bash
xcodegen generate
```

**Step 3: Build and verify**

```bash
xcodebuild build -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64'
```

Expected: BUILD SUCCEEDED. App launches as menu bar icon with no Dock icon.

**Step 4: Commit**

```bash
git add Countdown/ CountdownTests/ project.yml Countdown.xcodeproj
git commit -m "Scaffold Xcode project for menu bar countdown app"
```

---

### Task 2: Keychain Helper

Build a small Keychain wrapper for storing and retrieving OAuth tokens.

**Files:**
- Create: `Countdown/Keychain.swift`
- Create: `CountdownTests/KeychainTests.swift`

**Step 1: Write the failing tests**

`CountdownTests/KeychainTests.swift`:
```swift
// ABOUTME: Tests for Keychain storage operations.
// ABOUTME: Verifies save, load, update, and delete of token data.

import Testing
import Foundation
@testable import Countdown

@Suite("Keychain")
struct KeychainTests {
    // Use a unique service per test run to avoid collisions
    let service = "com.countdown.test.\(UUID().uuidString)"
    let account = "test-account"

    @Test func saveAndLoad() throws {
        let data = Data("test-token".utf8)
        try Keychain.save(data, service: service, account: account)
        let loaded = try Keychain.load(service: service, account: account)
        #expect(loaded == data)
        try Keychain.delete(service: service, account: account)
    }

    @Test func loadNonexistentThrows() {
        #expect(throws: KeychainError.itemNotFound) {
            try Keychain.load(service: service, account: account)
        }
    }

    @Test func saveOverwritesExisting() throws {
        let first = Data("first".utf8)
        let second = Data("second".utf8)
        try Keychain.save(first, service: service, account: account)
        try Keychain.save(second, service: service, account: account)
        let loaded = try Keychain.load(service: service, account: account)
        #expect(loaded == second)
        try Keychain.delete(service: service, account: account)
    }

    @Test func deleteRemovesItem() throws {
        let data = Data("delete-me".utf8)
        try Keychain.save(data, service: service, account: account)
        try Keychain.delete(service: service, account: account)
        #expect(throws: KeychainError.itemNotFound) {
            try Keychain.load(service: service, account: account)
        }
    }

    @Test func deleteNonexistentDoesNotThrow() throws {
        try Keychain.delete(service: service, account: account)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: FAIL — `Keychain` type does not exist.

**Step 3: Implement Keychain**

`Countdown/Keychain.swift`:
```swift
// ABOUTME: Stores and retrieves sensitive data (OAuth tokens) in the macOS Keychain.
// ABOUTME: Uses Security framework's kSecClassGenericPassword with service+account keys.

import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case invalidData
}

enum Keychain {
    static func save(_ data: Data, service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ]
            let attributes: [CFString: Any] = [kSecValueData: data]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func load(service: String, account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { throw KeychainError.itemNotFound }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = result as? Data else { throw KeychainError.invalidData }
        return data
    }

    static func delete(service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: All 5 Keychain tests PASS.

**Step 5: Commit**

```bash
git add Countdown/Keychain.swift CountdownTests/KeychainTests.swift
git commit -m "Add Keychain helper for secure token storage"
```

---

### Task 3: Google OAuth Configuration and PKCE

Build the Config loader and PKCE generation.

**Files:**
- Create: `Countdown/Config.swift`
- Create: `Countdown/PKCE.swift`
- Create: `Countdown/Config.plist` (template)
- Create: `CountdownTests/PKCETests.swift`
- Create: `CountdownTests/ConfigTests.swift`

**Step 1: Write the failing tests**

`CountdownTests/PKCETests.swift`:
```swift
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
        // Manually compute expected challenge
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
```

`CountdownTests/ConfigTests.swift`:
```swift
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
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: FAIL — `PKCE` and `Config` types do not exist.

**Step 3: Implement PKCE and Config**

`Countdown/PKCE.swift`:
```swift
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
```

`Countdown/Config.swift`:
```swift
// ABOUTME: Loads Google OAuth client credentials from a bundled plist.
// ABOUTME: Returns nil when the plist is missing so the UI can show setup instructions.

import Foundation

struct Config {
    let clientID: String
    let clientSecret: String

    static func load(from name: String = "Config") -> Config? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let clientID = dict["GOOGLE_CLIENT_ID"] as? String,
              let clientSecret = dict["GOOGLE_CLIENT_SECRET"] as? String,
              !clientID.isEmpty,
              !clientSecret.isEmpty
        else {
            return nil
        }
        return Config(clientID: clientID, clientSecret: clientSecret)
    }
}
```

Create `Countdown/Config.plist` (template — user fills in their values):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GOOGLE_CLIENT_ID</key>
    <string></string>
    <key>GOOGLE_CLIENT_SECRET</key>
    <string></string>
</dict>
</plist>
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: All PKCE and Config tests PASS.

**Step 5: Commit**

```bash
git add Countdown/PKCE.swift Countdown/Config.swift Countdown/Config.plist CountdownTests/PKCETests.swift CountdownTests/ConfigTests.swift
git commit -m "Add PKCE generation and OAuth config loader"
```

---

### Task 4: Google OAuth Authentication

Build the full OAuth flow: browser launch, redirect listener, token exchange, token refresh, revocation.

**Files:**
- Create: `Countdown/GoogleAuth.swift`
- Create: `CountdownTests/GoogleAuthTests.swift`

**Step 1: Write the failing tests**

Focus on the testable parts: URL building, token parsing, refresh logic. The browser/listener flow is integration-level and tested manually.

`CountdownTests/GoogleAuthTests.swift`:
```swift
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
```

Create `CountdownTests/MockURLProtocol.swift`:
```swift
// ABOUTME: Mock URL protocol for intercepting HTTP requests in tests.
// ABOUTME: Uses an actor for thread-safe handler storage.

import Foundation

actor MockRequestHandler {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private var handler: Handler?

    func set(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func handle(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let handler else {
            fatalError("MockRequestHandler: no handler set")
        }
        return try handler(request)
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static let requestHandler = MockRequestHandler()

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task {
            do {
                let (response, data) = try await Self.requestHandler.handle(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: FAIL — `GoogleAuth` type does not exist.

**Step 3: Implement GoogleAuth**

`Countdown/GoogleAuth.swift`:
```swift
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

struct TokenResponse: Decodable {
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

struct RefreshedToken: Decodable {
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
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": "http://127.0.0.1:\(redirectPort)",
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier,
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
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token",
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

    private static func formEncode(_ params: [String: String]) -> Data {
        params
            .map { k, v in
                let key = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
                let val = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
                return "\(key)=\(val)"
            }
            .joined(separator: "&")
            .data(using: .utf8)!
    }
}
```

Create `Countdown/RedirectListener.swift`:
```swift
// ABOUTME: Listens on a localhost port for the OAuth redirect callback.
// ABOUTME: Extracts the authorisation code from the browser redirect and sends a success page.

import Foundation
import Network

final class RedirectListener {
    private let listener: NWListener
    let port: UInt16

    init() throws {
        // Use port 0 to let the OS assign an available port
        listener = try NWListener(using: .tcp, on: .any)
        listener.start(queue: .main)

        // Get the actual assigned port
        guard let assignedPort = listener.port?.rawValue else {
            throw GoogleAuthError.listenerFailed
        }
        self.port = assignedPort
    }

    func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection, continuation: continuation)
            }
        }
    }

    private func handle(
        connection: NWConnection,
        continuation: CheckedContinuation<String, Error>
    ) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            defer {
                self?.listener.cancel()
            }

            guard let data, let request = String(data: data, encoding: .utf8) else {
                continuation.resume(throwing: GoogleAuthError.missingCode)
                connection.cancel()
                return
            }

            let firstLine = request.components(separatedBy: "\r\n").first ?? ""
            let path = firstLine.components(separatedBy: " ").dropFirst().first ?? ""
            let components = URLComponents(string: "http://localhost\(path)")
            let code = components?.queryItems?.first(where: { $0.name == "code" })?.value

            let html = code != nil
                ? "<html><body><h2>Authorisation successful. You may close this window.</h2></body></html>"
                : "<html><body><h2>Authorisation failed.</h2></body></html>"
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"

            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })

            if let code {
                continuation.resume(returning: code)
            } else {
                continuation.resume(throwing: GoogleAuthError.missingCode)
            }
        }
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: All GoogleAuth tests PASS.

**Step 5: Commit**

```bash
git add Countdown/GoogleAuth.swift Countdown/RedirectListener.swift CountdownTests/GoogleAuthTests.swift CountdownTests/MockURLProtocol.swift
git commit -m "Add Google OAuth flow with PKCE and local redirect listener"
```

---

### Task 5: Calendar API Client

Build the calendar event fetching and parsing.

**Files:**
- Create: `Countdown/CalendarEvent.swift`
- Create: `Countdown/CalendarClient.swift`
- Create: `CountdownTests/CalendarClientTests.swift`

**Step 1: Write the failing tests**

`CountdownTests/CalendarClientTests.swift`:
```swift
// ABOUTME: Tests for Google Calendar API event fetching and response parsing.
// ABOUTME: Uses MockURLProtocol to simulate API responses.

import Testing
import Foundation
@testable import Countdown

@Suite("CalendarClient", .serialized)
struct CalendarClientTests {
    let session = MockURLProtocol.makeSession()

    @Test func parsesTimedEvents() async throws {
        let json = """
        {
            "items": [
                {
                    "id": "evt1",
                    "summary": "Team Standup",
                    "status": "confirmed",
                    "start": { "dateTime": "2026-03-01T10:00:00Z" },
                    "end": { "dateTime": "2026-03-01T10:30:00Z" },
                    "attendees": [
                        { "email": "me@test.com", "self": true, "responseStatus": "accepted" },
                        { "email": "bob@test.com", "responseStatus": "accepted" }
                    ]
                }
            ]
        }
        """
        await MockURLProtocol.requestHandler.set { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let client = CalendarClient(session: session)
        let events = try await client.fetchEvents(
            accessToken: "test-token",
            from: Date(),
            to: Date().addingTimeInterval(3600)
        )

        #expect(events.count == 1)
        #expect(events[0].summary == "Team Standup")
        #expect(events[0].hasOtherAttendees == true)
    }

    @Test func filtersAllDayEvents() async throws {
        let json = """
        {
            "items": [
                {
                    "id": "allday",
                    "summary": "Holiday",
                    "status": "confirmed",
                    "start": { "date": "2026-03-01" },
                    "end": { "date": "2026-03-02" }
                }
            ]
        }
        """
        await MockURLProtocol.requestHandler.set { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let client = CalendarClient(session: session)
        let events = try await client.fetchEvents(
            accessToken: "test-token",
            from: Date(),
            to: Date().addingTimeInterval(3600)
        )

        // All-day events should be excluded (they're not meetings)
        #expect(events.isEmpty)
    }

    @Test func soloEventHasNoOtherAttendees() async throws {
        let json = """
        {
            "items": [
                {
                    "id": "solo",
                    "summary": "Focus Time",
                    "status": "confirmed",
                    "start": { "dateTime": "2026-03-01T14:00:00Z" },
                    "end": { "dateTime": "2026-03-01T15:00:00Z" }
                }
            ]
        }
        """
        await MockURLProtocol.requestHandler.set { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let client = CalendarClient(session: session)
        let events = try await client.fetchEvents(
            accessToken: "test-token",
            from: Date(),
            to: Date().addingTimeInterval(3600)
        )

        #expect(events.count == 1)
        #expect(events[0].hasOtherAttendees == false)
    }

    @Test func unauthorisedThrowsError() async throws {
        await MockURLProtocol.requestHandler.set { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }

        let client = CalendarClient(session: session)
        #expect(throws: CalendarClientError.unauthorised) {
            try await client.fetchEvents(
                accessToken: "expired",
                from: Date(),
                to: Date().addingTimeInterval(3600)
            )
        }
    }

    @Test func requestIncludesCorrectParameters() async throws {
        var capturedURL: URL?
        await MockURLProtocol.requestHandler.set { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"items":[]}"#.utf8))
        }

        let client = CalendarClient(session: session)
        _ = try await client.fetchEvents(
            accessToken: "test",
            from: Date(),
            to: Date().addingTimeInterval(3600)
        )

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        let params = Dictionary(
            uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) }
        )

        #expect(params["singleEvents"] == "true")
        #expect(params["orderBy"] == "startTime")
        #expect(params["timeMin"] != nil)
        #expect(params["timeMax"] != nil)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: FAIL — `CalendarClient` and `CalendarEvent` types do not exist.

**Step 3: Implement CalendarEvent and CalendarClient**

`Countdown/CalendarEvent.swift`:
```swift
// ABOUTME: Decodable models for Google Calendar API event responses.
// ABOUTME: Distinguishes timed events from all-day events and tracks attendee presence.

import Foundation

struct CalendarEventList: Decodable {
    let items: [RawCalendarEvent]?
}

struct RawCalendarEvent: Decodable {
    let id: String
    let summary: String?
    let status: String?
    let start: EventDateTime?
    let end: EventDateTime?
    let attendees: [EventAttendee]?
}

struct EventDateTime: Decodable {
    let dateTime: String?
    let date: String?

    var resolved: Date? {
        if let dt = dateTime {
            return ISO8601DateFormatter().date(from: dt)
        }
        return nil
    }

    var isAllDay: Bool {
        dateTime == nil && date != nil
    }
}

struct EventAttendee: Decodable {
    let email: String?
    let responseStatus: String?
    let isSelf: Bool?

    enum CodingKeys: String, CodingKey {
        case email, responseStatus
        case isSelf = "self"
    }
}

/// Processed calendar event with only the fields we need
struct CalendarEvent {
    let id: String
    let summary: String
    let startTime: Date
    let hasOtherAttendees: Bool
}
```

`Countdown/CalendarClient.swift`:
```swift
// ABOUTME: Fetches and parses events from the Google Calendar API.
// ABOUTME: Filters to timed, non-cancelled events and determines attendee presence.

import Foundation

enum CalendarClientError: Error {
    case unauthorised
    case httpError(Int)
}

final class CalendarClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchEvents(
        accessToken: String,
        from start: Date,
        to end: Date
    ) async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(
            string: "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        )!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: formatter.string(from: start)),
            URLQueryItem(name: "timeMax", value: formatter.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse

        guard http.statusCode != 401 else {
            throw CalendarClientError.unauthorised
        }
        guard http.statusCode == 200 else {
            throw CalendarClientError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(CalendarEventList.self, from: data)
        let rawEvents = decoded.items ?? []

        return rawEvents.compactMap { raw in
            // Skip all-day events
            guard let startDT = raw.start, !startDT.isAllDay,
                  let startTime = startDT.resolved else {
                return nil
            }

            // Skip cancelled events
            guard raw.status != "cancelled" else { return nil }

            let otherAttendees = (raw.attendees ?? []).filter { $0.isSelf != true }

            return CalendarEvent(
                id: raw.id,
                summary: raw.summary ?? "(No title)",
                startTime: startTime,
                hasOtherAttendees: !otherAttendees.isEmpty
            )
        }
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: All CalendarClient tests PASS.

**Step 5: Commit**

```bash
git add Countdown/CalendarEvent.swift Countdown/CalendarClient.swift CountdownTests/CalendarClientTests.swift
git commit -m "Add Calendar API client with event parsing and filtering"
```

---

### Task 6: Countdown Model

Build the central model that ties auth, calendar polling, and countdown state together.

**Files:**
- Create: `Countdown/CountdownModel.swift`
- Create: `CountdownTests/CountdownModelTests.swift`

**Step 1: Write the failing tests**

`CountdownTests/CountdownModelTests.swift`:
```swift
// ABOUTME: Tests for the countdown model's time-based colour and flash logic.
// ABOUTME: Verifies state transitions based on minutes remaining until an event.

import Testing
import Foundation
@testable import Countdown

@Suite("CountdownModel")
struct CountdownModelTests {
    @Test func noEventMeansHidden() {
        let model = CountdownModel()
        #expect(model.shouldShowOverlay == false)
    }

    @Test func eventWithin60MinutesShowsOverlay() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.minutesRemaining == 30)
    }

    @Test func colourIsGreenAt60Minutes() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        // At 60 minutes, progress is 0.0 (start of countdown)
        #expect(model.colourProgress < 0.05)
    }

    @Test func colourIsRedAt1Minute() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(60),
            hasOtherAttendees: true
        )
        model.updateState()
        // At 1 minute, progress should be very high
        #expect(model.colourProgress > 0.95)
    }

    @Test func flashesWithin1Minute() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isFlashing == true)
    }

    @Test func flashesDuringFirst5MinutesAfterStart() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-3 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isFlashing == true)
        #expect(model.minutesRemaining == 0)
    }

    @Test func stopsFlashingAfter5MinutesPastStart() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-6 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == false)
    }

    @Test func clickDismissesCurrentEvent() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "evt-1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isFlashing == true)

        model.dismiss()
        #expect(model.shouldShowOverlay == false)
    }

    @Test func meetingsOnlyFilterExcludesSoloEvents() {
        let model = CountdownModel()
        model.meetingsOnly = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus Time",
            startTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: false
        )
        model.updateState()
        #expect(model.shouldShowOverlay == false)
    }

    @Test func meetingsOnlyFilterIncludesMeetings() {
        let model = CountdownModel()
        model.meetingsOnly = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
    }

    @Test func allEventsShowsSoloEvents() {
        let model = CountdownModel()
        model.meetingsOnly = false
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus Time",
            startTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: false
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: FAIL — `CountdownModel` does not have the required properties.

**Step 3: Implement CountdownModel**

`Countdown/CountdownModel.swift`:
```swift
// ABOUTME: Central model tracking the next calendar event and countdown display state.
// ABOUTME: Computes colour, flash state, and visibility based on time remaining.

import Foundation
import Observation

@Observable
final class CountdownModel {
    var nextEvent: CalendarEvent?
    var meetingsOnly: Bool = false

    private(set) var shouldShowOverlay: Bool = false
    private(set) var minutesRemaining: Int = 0
    private(set) var colourProgress: Double = 0.0  // 0 = green (60 min), 1 = red (0 min)
    private(set) var isFlashing: Bool = false

    private var dismissedEventID: String?

    func updateState() {
        guard let event = nextEvent else {
            shouldShowOverlay = false
            return
        }

        // Apply meetings-only filter
        if meetingsOnly && !event.hasOtherAttendees {
            shouldShowOverlay = false
            return
        }

        // Skip dismissed events
        if event.id == dismissedEventID {
            shouldShowOverlay = false
            return
        }

        let secondsUntilStart = event.startTime.timeIntervalSinceNow
        let minutesUntil = secondsUntilStart / 60.0

        // More than 60 minutes away — hide
        if minutesUntil > 60 {
            shouldShowOverlay = false
            return
        }

        // More than 5 minutes past start — hide
        if minutesUntil < -5 {
            shouldShowOverlay = false
            return
        }

        shouldShowOverlay = true
        minutesRemaining = max(0, Int(ceil(minutesUntil)))

        // Colour progress: 0 at 60 min, 1 at 0 min
        if minutesUntil > 0 {
            colourProgress = 1.0 - (minutesUntil / 60.0)
        } else {
            colourProgress = 1.0
        }
        colourProgress = min(1.0, max(0.0, colourProgress))

        // Flash: within 1 minute before start through 5 minutes after
        isFlashing = minutesUntil < 1 && minutesUntil >= -5
    }

    func dismiss() {
        dismissedEventID = nextEvent?.id
        shouldShowOverlay = false
        isFlashing = false
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: All CountdownModel tests PASS.

**Step 5: Commit**

```bash
git add Countdown/CountdownModel.swift CountdownTests/CountdownModelTests.swift
git commit -m "Add countdown model with colour, flash, and filter logic"
```

---

### Task 7: Calendar Manager (Polling Coordinator)

Build the manager that ties auth, calendar client, and model together with periodic polling.

**Files:**
- Create: `Countdown/CalendarManager.swift`

**Step 1: Implement CalendarManager**

This is primarily a coordinator — its logic is integration-level. The components it calls (GoogleAuth, CalendarClient, CountdownModel) are already tested.

`Countdown/CalendarManager.swift`:
```swift
// ABOUTME: Coordinates calendar polling, token management, and model updates.
// ABOUTME: Polls Google Calendar every 60 seconds and feeds the next event to CountdownModel.

import Foundation

@Observable
final class CalendarManager {
    let model = CountdownModel()

    private(set) var isSignedIn: Bool = false
    private(set) var userEmail: String?
    private(set) var errorMessage: String?

    private let calendarClient = CalendarClient()
    private let keychainService = "com.countdown.google-oauth"
    private let keychainAccount = "tokens"

    private var refreshToken: String?
    private var accessToken: String?
    private var tokenExpiry: Date?
    private var pollingTimer: Timer?
    private var stateTimer: Timer?

    var config: Config?

    init() {
        loadStoredTokens()
    }

    // MARK: - Auth

    func signIn() async {
        guard let config else {
            errorMessage = "Config.plist not found. Add your Google OAuth credentials."
            return
        }

        do {
            let response = try await GoogleAuth.signIn(
                clientID: config.clientID,
                clientSecret: config.clientSecret
            )

            accessToken = response.accessToken
            refreshToken = response.refreshToken ?? refreshToken
            tokenExpiry = Date().addingTimeInterval(Double(response.expiresIn))

            saveTokens()
            isSignedIn = true
            errorMessage = nil

            startPolling()
        } catch {
            errorMessage = "Sign-in failed: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        if let token = refreshToken {
            try? await GoogleAuth.revokeToken(token)
        }

        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isSignedIn = false
        userEmail = nil
        model.nextEvent = nil

        try? Keychain.delete(service: keychainService, account: keychainAccount)
        stopPolling()
    }

    // MARK: - Polling

    func startPolling() {
        poll()

        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.poll()
        }

        // Update state every second for smooth countdown
        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.model.updateState()
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        stateTimer?.invalidate()
        stateTimer = nil
    }

    private func poll() {
        Task { @MainActor in
            await fetchEvents()
        }
    }

    private func fetchEvents() async {
        guard let config else { return }

        do {
            let token = try await validAccessToken(config: config)
            let now = Date()
            let events = try await calendarClient.fetchEvents(
                accessToken: token,
                from: now,
                to: now.addingTimeInterval(60 * 60)
            )

            // Pick the nearest event, respecting the filter
            let filtered: [CalendarEvent]
            if model.meetingsOnly {
                filtered = events.filter { $0.hasOtherAttendees }
            } else {
                filtered = events
            }

            model.nextEvent = filtered.first
            model.updateState()
            errorMessage = nil
        } catch CalendarClientError.unauthorised {
            // Token might be revoked — force re-auth
            isSignedIn = false
            errorMessage = "Session expired. Please sign in again."
            stopPolling()
        } catch {
            errorMessage = "Failed to fetch events: \(error.localizedDescription)"
        }
    }

    // MARK: - Token Management

    private func validAccessToken(config: Config) async throws -> String {
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date().addingTimeInterval(60) {
            return token
        }

        guard let refresh = refreshToken else {
            throw GoogleAuthError.refreshFailed(0, Data())
        }

        let refreshed = try await GoogleAuth.refreshAccessToken(
            refreshToken: refresh,
            clientID: config.clientID,
            clientSecret: config.clientSecret
        )

        accessToken = refreshed.accessToken
        tokenExpiry = Date().addingTimeInterval(Double(refreshed.expiresIn))
        saveTokens()
        return refreshed.accessToken
    }

    // MARK: - Persistence

    private struct StoredTokens: Codable {
        let refreshToken: String
        var accessToken: String?
        var tokenExpiry: Date?
    }

    private func saveTokens() {
        guard let refreshToken else { return }
        let stored = StoredTokens(
            refreshToken: refreshToken,
            accessToken: accessToken,
            tokenExpiry: tokenExpiry
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? Keychain.save(data, service: keychainService, account: keychainAccount)
    }

    private func loadStoredTokens() {
        guard let data = try? Keychain.load(service: keychainService, account: keychainAccount),
              let stored = try? JSONDecoder().decode(StoredTokens.self, from: data)
        else { return }

        refreshToken = stored.refreshToken
        accessToken = stored.accessToken
        tokenExpiry = stored.tokenExpiry
        isSignedIn = true
    }
}
```

**Step 2: Build to verify compilation**

```bash
xcodebuild build -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add Countdown/CalendarManager.swift
git commit -m "Add calendar manager coordinating auth, polling, and model updates"
```

---

### Task 8: Overlay Circle View

Build the SwiftUI circle view with colour transitions and flash animation.

**Files:**
- Create: `Countdown/CircleView.swift`

**Step 1: Implement CircleView**

`Countdown/CircleView.swift`:
```swift
// ABOUTME: Animated countdown circle showing minutes until the next calendar event.
// ABOUTME: Transitions from green to red and pulses when the event is imminent.

import SwiftUI

struct CircleView: View {
    let minutesRemaining: Int
    let colourProgress: Double  // 0 = green, 1 = red
    let isFlashing: Bool
    let onDismiss: () -> Void

    @State private var flashOpacity: Double = 1.0

    private var circleColour: Color {
        if colourProgress > 55.0 / 60.0 {
            return .red
        }
        // Interpolate green -> orange -> red
        return Color(
            red: min(1.0, colourProgress * 2),
            green: max(0.0, 1.0 - colourProgress * 1.5),
            blue: 0
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(circleColour)
                .opacity(isFlashing ? flashOpacity : 0.85)
                .frame(width: 80, height: 80)

            Text("\(minutesRemaining)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .onTapGesture {
            onDismiss()
        }
        .onChange(of: isFlashing) { _, flashing in
            if flashing {
                startFlashing()
            } else {
                flashOpacity = 1.0
            }
        }
        .onAppear {
            if isFlashing {
                startFlashing()
            }
        }
    }

    private func startFlashing() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            flashOpacity = 0.4
        }
    }
}
```

**Step 2: Build to verify compilation**

```bash
xcodebuild build -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add Countdown/CircleView.swift
git commit -m "Add animated countdown circle view with colour transitions and flash"
```

---

### Task 9: Overlay Window (NSPanel)

Build the floating overlay panel and wire it to the model.

**Files:**
- Create: `Countdown/OverlayPanel.swift`
- Modify: `Countdown/AppDelegate.swift`

**Step 1: Implement OverlayPanel**

`Countdown/OverlayPanel.swift`:
```swift
// ABOUTME: Floating borderless panel that displays the countdown circle on the desktop.
// ABOUTME: Positions itself in the bottom-right corner and stays above all windows.

import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    init<Content: View>(content: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: content)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        contentView = hostingView

        positionBottomRight()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 20
        let frame = NSRect(
            x: screen.visibleFrame.maxX - 100 - padding,
            y: screen.visibleFrame.minY + padding,
            width: 100,
            height: 100
        )
        setFrame(frame, display: true)
    }
}
```

**Step 2: Wire up AppDelegate to manage the overlay**

Update `Countdown/AppDelegate.swift`:
```swift
// ABOUTME: Manages app activation policy to suppress Dock icon.
// ABOUTME: Owns the floating overlay panel lifecycle.

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayPanel: OverlayPanel?
    var calendarManager: CalendarManager?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func setupOverlay(manager: CalendarManager) {
        self.calendarManager = manager

        let circleContent = OverlayContent(manager: manager)
        let panel = OverlayPanel(content: circleContent)
        self.overlayPanel = panel

        updateOverlayVisibility()
    }

    func updateOverlayVisibility() {
        guard let model = calendarManager?.model else { return }
        if model.shouldShowOverlay {
            overlayPanel?.orderFront(nil)
        } else {
            overlayPanel?.orderOut(nil)
        }
    }
}

struct OverlayContent: View {
    @Bindable var manager: CalendarManager

    var body: some View {
        Group {
            if manager.model.shouldShowOverlay {
                CircleView(
                    minutesRemaining: manager.model.minutesRemaining,
                    colourProgress: manager.model.colourProgress,
                    isFlashing: manager.model.isFlashing,
                    onDismiss: { manager.model.dismiss() }
                )
            }
        }
        .frame(width: 100, height: 100)
        .background(.clear)
        .onChange(of: manager.model.shouldShowOverlay) { _, visible in
            if visible {
                (NSApp.delegate as? AppDelegate)?.overlayPanel?.orderFront(nil)
            } else {
                (NSApp.delegate as? AppDelegate)?.overlayPanel?.orderOut(nil)
            }
        }
    }
}
```

**Step 3: Build to verify compilation**

```bash
xcodebuild build -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add Countdown/OverlayPanel.swift Countdown/AppDelegate.swift
git commit -m "Add floating overlay panel positioned bottom-right of screen"
```

---

### Task 10: Settings View (Menu Bar Popover)

Build the settings UI shown when clicking the menu bar icon.

**Files:**
- Create: `Countdown/SettingsView.swift`
- Modify: `Countdown/CountdownApp.swift`

**Step 1: Implement SettingsView**

`Countdown/SettingsView.swift`:
```swift
// ABOUTME: Menu bar popover showing event status, Google account controls, and event filter.
// ABOUTME: Provides connect/disconnect for Google Calendar and a meetings-only toggle.

import SwiftUI

struct SettingsView: View {
    @Bindable var manager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status
            statusSection

            Divider()

            // Google Account
            accountSection

            Divider()

            // Event filter
            filterSection

            Spacer()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 280, height: 260)
    }

    @ViewBuilder
    private var statusSection: some View {
        if let event = manager.model.nextEvent,
           manager.model.shouldShowOverlay {
            Text("Next: \(event.summary) in \(manager.model.minutesRemaining) min")
                .font(.headline)
        } else if manager.isSignedIn {
            Text("No upcoming events")
                .font(.headline)
                .foregroundStyle(.secondary)
        } else {
            Text("Not connected")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Google Account")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if manager.config == nil {
                Text("Add your Google OAuth credentials to Config.plist to get started.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if manager.isSignedIn {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected")
                    Spacer()
                    Button("Disconnect") {
                        Task { await manager.signOut() }
                    }
                }
            } else {
                Button("Connect Google Account") {
                    Task { await manager.signIn() }
                }
                .buttonStyle(.borderedProminent)
            }

            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show countdown for")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("", selection: $manager.model.meetingsOnly) {
                Text("All events").tag(false)
                Text("Meetings only").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }
}
```

**Step 2: Wire up CountdownApp**

Update `Countdown/CountdownApp.swift`:
```swift
// ABOUTME: App entry point for the meeting countdown menu bar app.
// ABOUTME: Configures MenuBarExtra with .window style and wires up AppDelegate.

import SwiftUI

@main
struct CountdownApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var manager = CalendarManager()

    var body: some Scene {
        MenuBarExtra {
            SettingsView(manager: manager)
        } label: {
            MenuBarIcon(model: manager.model)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: manager.isSignedIn) { _, _ in
            // Trigger overlay setup once signed in
        }
        .defaultAppStorage(UserDefaults.standard)
    }

    init() {
        let mgr = CalendarManager()
        mgr.config = Config.load()
        _manager = State(initialValue: mgr)
    }
}

struct MenuBarIcon: View {
    let model: CountdownModel

    var body: some View {
        Image(systemName: "circle.fill")
            .foregroundStyle(model.shouldShowOverlay ? .red : .gray)
    }
}
```

Wait — there's a problem. We need the `AppDelegate` to set up the overlay, and it needs access to the `CalendarManager`. Let me adjust the wiring.

Update `Countdown/CountdownApp.swift` properly:
```swift
// ABOUTME: App entry point for the meeting countdown menu bar app.
// ABOUTME: Configures MenuBarExtra with .window style and wires up AppDelegate.

import SwiftUI

@main
struct CountdownApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var manager: CalendarManager

    init() {
        let mgr = CalendarManager()
        mgr.config = Config.load()
        _manager = State(initialValue: mgr)
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsView(manager: manager)
                .onAppear {
                    appDelegate.setupOverlay(manager: manager)
                    if manager.isSignedIn {
                        manager.startPolling()
                    }
                }
        } label: {
            Image(systemName: "circle.fill")
                .foregroundStyle(manager.model.shouldShowOverlay ? .red : .gray)
        }
        .menuBarExtraStyle(.window)
    }
}
```

**Step 3: Build to verify compilation**

```bash
xcodebuild build -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add Countdown/SettingsView.swift Countdown/CountdownApp.swift
git commit -m "Add settings view and wire up app entry point"
```

---

### Task 11: Persist User Preferences

Store the meetings-only toggle in UserDefaults so it survives app restarts.

**Files:**
- Modify: `Countdown/CountdownModel.swift`
- Modify: `Countdown/CalendarManager.swift`

**Step 1: Add UserDefaults persistence for meetingsOnly**

In `CountdownModel.swift`, change `meetingsOnly` to read/write from UserDefaults:

```swift
var meetingsOnly: Bool {
    get { UserDefaults.standard.bool(forKey: "meetingsOnly") }
    set { UserDefaults.standard.set(newValue, forKey: "meetingsOnly") }
}
```

Remove the stored property `var meetingsOnly: Bool = false` and replace with the computed property above.

**Step 2: Build and run tests**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20
```

Expected: All tests PASS (model tests set `meetingsOnly` which now writes to UserDefaults — acceptable in tests).

**Step 3: Commit**

```bash
git add Countdown/CountdownModel.swift
git commit -m "Persist meetings-only preference in UserDefaults"
```

---

### Task 12: End-to-End Build and Manual Test

Final verification that the whole app builds, runs, and the UI is functional.

**Step 1: Full build**

```bash
xcodebuild build -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

**Step 2: Run all tests**

```bash
xcodebuild test -project Countdown.xcodeproj -scheme Countdown -destination 'platform=macOS,arch=arm64' 2>&1 | tail -30
```

Expected: All tests PASS.

**Step 3: Manual smoke test**

1. Launch the app — verify menu bar icon appears, no Dock icon
2. Click menu bar icon — verify settings popover opens
3. Verify "Config.plist" warning appears (credentials not filled in)
4. Fill in Google OAuth credentials in Config.plist
5. Click "Connect Google Account" — verify browser opens to Google consent
6. Complete sign-in — verify "Connected" status appears
7. If events exist within 60 min — verify circle overlay appears bottom-right
8. Verify circle colour matches time remaining
9. Test "Meetings only" toggle
10. Click the circle — verify it dismisses
11. Test "Disconnect" — verify sign-out works

**Step 4: Final commit**

```bash
git add -A
git commit -m "Complete meeting countdown overlay app"
```
