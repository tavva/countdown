// ABOUTME: Coordinates calendar polling, token management, and model updates.
// ABOUTME: Polls Google Calendar every 60 seconds and feeds the next event to CountdownModel.

import Foundation
import Observation

@MainActor
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
            Task { @MainActor in self?.poll() }
        }

        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.updateState() }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        stateTimer?.invalidate()
        stateTimer = nil
    }

    private func poll() {
        Task { @MainActor [weak self] in
            await self?.fetchEvents()
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
