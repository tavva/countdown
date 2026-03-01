// ABOUTME: Tests for Google Calendar API event and calendar list fetching.
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
        await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
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
        #expect(events[0].endTime == ISO8601DateFormatter().date(from: "2026-03-01T10:30:00Z"))
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
        await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
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
        await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
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
        await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("{}".utf8))
        }

        let client = CalendarClient(session: session)
        await #expect(throws: CalendarClientError.unauthorised) {
            try await client.fetchEvents(
                accessToken: "expired",
                from: Date(),
                to: Date().addingTimeInterval(3600)
            )
        }
    }

    @Test func requestIncludesCorrectParameters() async throws {
        nonisolated(unsafe) var capturedURL: URL?
        await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
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

    @Test func fetchEventsUsesProvidedCalendarID() async throws {
        nonisolated(unsafe) var capturedURL: URL?
        await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"items":[]}"#.utf8))
        }

        let client = CalendarClient(session: session)
        _ = try await client.fetchEvents(
            accessToken: "test",
            calendarID: "work@example.com",
            from: Date(),
            to: Date().addingTimeInterval(3600)
        )

        #expect(capturedURL!.path.contains("/calendars/work@example.com/events"))
    }

    @Test func fetchEventsEncodesCalendarIDWithHash() async throws {
        nonisolated(unsafe) var capturedURL: URL?
        await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"items":[]}"#.utf8))
        }

        let client = CalendarClient(session: session)
        _ = try await client.fetchEvents(
            accessToken: "test",
            calendarID: "en.uk#holiday@group.v.calendar.google.com",
            from: Date(),
            to: Date().addingTimeInterval(3600)
        )

        let urlString = capturedURL!.absoluteString
        #expect(urlString.contains("en.uk%23holiday"))
        #expect(capturedURL!.query != nil)
    }

    @Test func fetchCalendarsParsesResponse() async throws {
        let json = """
        {
            "items": [
                {
                    "id": "primary",
                    "summary": "Work",
                    "backgroundColor": "#4285f4"
                },
                {
                    "id": "personal@gmail.com",
                    "summary": "Personal",
                    "backgroundColor": "#0b8043"
                }
            ]
        }
        """
        await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let client = CalendarClient(session: session)
        let calendars = try await client.fetchCalendars(accessToken: "test-token")

        #expect(calendars.count == 2)
        #expect(calendars[0].id == "primary")
        #expect(calendars[0].summary == "Work")
        #expect(calendars[0].backgroundColor == "#4285f4")
        #expect(calendars[1].id == "personal@gmail.com")
    }
}
