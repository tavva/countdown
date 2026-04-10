// ABOUTME: Tests for CalendarManager settings changes and token retry behaviour.
// ABOUTME: Verifies settings updates, sign-out state, and 401 retry with token refresh.

import Testing
import Foundation
@testable import Countdown

/// Isolated mock URL protocol for CalendarManager tests to avoid sharing
/// state with CalendarClient tests that may run concurrently.
private final class ManagerMockProtocol: URLProtocol, @unchecked Sendable {
    static let requestHandler = MockRequestHandler()

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ManagerMockProtocol.self]
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

@Suite("CalendarManager", .serialized)
struct CalendarManagerTests {
    private let _snapshot = DefaultsSnapshot(keys: [
        "meetingsOnly", "enabledCalendarIDs",
        "hideDeclinedEvents", "hideTasksAndBirthdays",
    ])

    @Test @MainActor func setMeetingsOnlyUpdatesOverlayImmediately() {
        let manager = CalendarManager()
        manager.model.setEvents([])
        manager.model.meetingsOnly = false
        manager.model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus Time",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false
        )
        manager.model.updateState()
        #expect(manager.model.shouldShowOverlay == true)
        #expect(manager.model.isIdle == false)

        manager.setMeetingsOnly(true)

        #expect(manager.model.meetingsOnly == true)
        #expect(manager.model.shouldShowOverlay == true)
        #expect(manager.model.isIdle == true)
    }

    @Test @MainActor func signOutClearsCountdownState() async {
        let manager = CalendarManager()
        manager.model.setEvents([])
        manager.model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        manager.model.updateState()
        #expect(manager.model.shouldShowOverlay == true)
        #expect(manager.model.isIdle == false)

        await manager.signOut()

        #expect(manager.model.nextEvent == nil)
        #expect(manager.model.shouldShowOverlay == true)
        #expect(manager.model.isIdle == true)
    }

    @Test @MainActor func retriesWithRefreshedTokenOn401() async {
        let session = ManagerMockProtocol.makeSession()
        let manager = CalendarManager(session: session)
        manager.config = Config(clientID: "test-id", clientSecret: "test-secret")
        manager.isSignedIn = true
        manager.refreshToken = "valid-refresh"
        manager.accessToken = "stale-token"
        manager.tokenExpiry = Date().addingTimeInterval(3600)

        nonisolated(unsafe) var apiCallCount = 0

        await ManagerMockProtocol.requestHandler.set(forHost: "oauth2.googleapis.com") { request in
            let json = #"{"access_token":"fresh-token","expires_in":3600}"#
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        await ManagerMockProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
            apiCallCount += 1
            if apiCallCount == 1 {
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil
                )!
                return (response, Data("{}".utf8))
            }
            let json = #"{"items":[]}"#
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        await manager.fetchEvents()

        #expect(manager.isSignedIn == true)
        #expect(manager.errorMessage == nil)
    }

    @Test @MainActor func signsOutAfterRetryAlsoFails() async {
        let session = ManagerMockProtocol.makeSession()
        let manager = CalendarManager(session: session)
        manager.config = Config(clientID: "test-id", clientSecret: "test-secret")
        manager.refreshToken = "valid-refresh"
        manager.accessToken = "stale-token"
        manager.tokenExpiry = Date().addingTimeInterval(3600)

        await ManagerMockProtocol.requestHandler.set(forHost: "oauth2.googleapis.com") { request in
            let json = #"{"access_token":"also-bad-token","expires_in":3600}"#
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        await ManagerMockProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }

        await manager.fetchEvents()

        #expect(manager.isSignedIn == false)
        #expect(manager.errorMessage == "Session expired. Please sign in again.")
        #expect(manager.model.isLoading == false)
    }

    @Test @MainActor func signsOutWhenRefreshTokenIsInvalid() async {
        let session = ManagerMockProtocol.makeSession()
        let manager = CalendarManager(session: session)
        manager.config = Config(clientID: "test-id", clientSecret: "test-secret")
        manager.refreshToken = "expired-refresh"
        manager.accessToken = nil
        manager.tokenExpiry = nil

        await ManagerMockProtocol.requestHandler.set(forHost: "oauth2.googleapis.com") { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"error":"invalid_grant"}"#.utf8))
        }

        await manager.fetchEvents()

        #expect(manager.isSignedIn == false)
        #expect(manager.errorMessage == "Session expired. Please sign in again.")
        #expect(manager.model.isLoading == false)
    }

    @Test @MainActor func setHideDeclinedEventsUpdatesOverlayImmediately() {
        let manager = CalendarManager()
        manager.model.setEvents([])
        manager.model.hideDeclinedEvents = false
        manager.model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Declined: Team Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        manager.model.updateState()
        #expect(manager.model.isIdle == false)

        manager.setHideDeclinedEvents(true)

        #expect(manager.model.hideDeclinedEvents == true)
        #expect(manager.model.isIdle == true)
    }

    @Test @MainActor func setHideTasksAndBirthdaysUpdatesOverlayImmediately() {
        let manager = CalendarManager()
        manager.model.setEvents([])
        manager.model.meetingsOnly = false
        manager.model.hideTasksAndBirthdays = false
        manager.model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Buy milk",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false,
            eventType: "task"
        )
        manager.model.updateState()
        #expect(manager.model.isIdle == false)

        manager.setHideTasksAndBirthdays(true)

        #expect(manager.model.hideTasksAndBirthdays == true)
        #expect(manager.model.isIdle == true)
    }

    @Test @MainActor func fetchEventsFiltersHiddenEventTypesBeforeSelectingNextEvent() async {
        let session = ManagerMockProtocol.makeSession()
        let manager = CalendarManager(session: session)
        manager.config = Config(clientID: "test-id", clientSecret: "test-secret")
        manager.isSignedIn = true
        manager.refreshToken = "valid-refresh"
        manager.accessToken = "valid-token"
        manager.tokenExpiry = Date().addingTimeInterval(3600)
        manager.model.meetingsOnly = false
        manager.model.hideTasksAndBirthdays = true

        // Task starts earlier than the meeting. Without the pre-filter,
        // CountdownModel.setEvents would pick the task as nextEvent. With
        // the pre-filter the task is dropped and the meeting wins.
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let taskStart = formatter.string(from: now.addingTimeInterval(10 * 60))
        let taskEnd = formatter.string(from: now.addingTimeInterval(15 * 60))
        let meetingStart = formatter.string(from: now.addingTimeInterval(20 * 60))
        let meetingEnd = formatter.string(from: now.addingTimeInterval(50 * 60))

        await ManagerMockProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
            let path = request.url!.path
            let json: String
            if path.contains("/calendarList") {
                json = ##"{"items":[{"id":"primary","summary":"Work","backgroundColor":"#4285f4"}]}"##
            } else {
                json = """
                {
                    "items": [
                        {
                            "id": "task1",
                            "summary": "Buy milk",
                            "status": "confirmed",
                            "eventType": "task",
                            "start": { "dateTime": "\(taskStart)" },
                            "end": { "dateTime": "\(taskEnd)" }
                        },
                        {
                            "id": "meeting1",
                            "summary": "Standup",
                            "status": "confirmed",
                            "eventType": "default",
                            "start": { "dateTime": "\(meetingStart)" },
                            "end": { "dateTime": "\(meetingEnd)" }
                        }
                    ]
                }
                """
            }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        await manager.fetchEvents()

        #expect(manager.model.nextEvent?.id == "meeting1")
    }

    @Test @MainActor func setMeetingsOnlyToFalseShowsSoloEvents() {
        let manager = CalendarManager()
        manager.model.setEvents([])
        manager.model.meetingsOnly = true
        manager.model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus Time",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false
        )
        manager.model.updateState()
        #expect(manager.model.shouldShowOverlay == true)
        #expect(manager.model.isIdle == true)

        manager.setMeetingsOnly(false)

        #expect(manager.model.meetingsOnly == false)
        #expect(manager.model.shouldShowOverlay == true)
        #expect(manager.model.isIdle == false)
    }
}
