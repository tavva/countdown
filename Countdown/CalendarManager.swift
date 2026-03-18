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
    private(set) var calendars: [CalendarInfo] = []

    var enabledCalendarIDs: Set<String> {
        get {
            let stored = UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs")
            guard let stored else { return [] }
            return Set(stored)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "enabledCalendarIDs")
        }
    }

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

            await fetchEvents()
            startPolling(skipInitialFetch: true)
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
        model.setEvents([])
        model.updateState()
        calendars = []
        UserDefaults.standard.removeObject(forKey: "enabledCalendarIDs")

        try? Keychain.delete(service: keychainService, account: keychainAccount)
        stopPolling()
    }

    // MARK: - Calendar Selection

    func isCalendarEnabled(_ id: String) -> Bool {
        let enabled = enabledCalendarIDs
        return enabled.isEmpty || enabled.contains(id)
    }

    func toggleCalendar(_ id: String) {
        var enabled = enabledCalendarIDs
        if enabled.isEmpty {
            // Switching from "all enabled" to explicit set: add all except the toggled one
            enabled = Set(calendars.map(\.id))
            enabled.remove(id)
        } else if enabled.contains(id) {
            enabled.remove(id)
        } else {
            enabled.insert(id)
            // If all calendars are now enabled, reset to empty (= all)
            if enabled == Set(calendars.map(\.id)) {
                enabled = []
            }
        }
        enabledCalendarIDs = enabled
        poll()
    }

    func setMeetingsOnly(_ value: Bool) {
        model.meetingsOnly = value
        model.updateState()
        poll()
    }

    // MARK: - Polling

    func startPolling(skipInitialFetch: Bool = false) {
        if !skipInitialFetch { poll() }

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

            let fetchedCalendars = try await calendarClient.fetchCalendars(accessToken: token)
            calendars = fetchedCalendars

            let now = Date()
            let end = now.addingTimeInterval(60 * 60)

            let enabledIDs = enabledCalendarIDs
            let calendarsToFetch = fetchedCalendars.filter { cal in
                enabledIDs.isEmpty || enabledIDs.contains(cal.id)
            }

            var allEvents: [CalendarEvent] = []
            for cal in calendarsToFetch {
                let events = try await calendarClient.fetchEvents(
                    accessToken: token,
                    calendarID: cal.id,
                    from: now,
                    to: end
                )
                allEvents.append(contentsOf: events)
            }

            allEvents.sort { $0.startTime < $1.startTime }

            let filtered: [CalendarEvent]
            if model.meetingsOnly {
                filtered = allEvents.filter { $0.hasOtherAttendees }
            } else {
                filtered = allEvents
            }

            model.setEvents(filtered)
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
