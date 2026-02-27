// ABOUTME: Fetches calendar lists and events from the Google Calendar API.
// ABOUTME: Filters to timed, non-cancelled events and determines attendee presence.

import Foundation

enum CalendarClientError: Error, Equatable {
    case unauthorised
    case httpError(Int)
}

final class CalendarClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchEvents(
        accessToken: String,
        calendarID: String = "primary",
        from start: Date,
        to end: Date
    ) async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(
            string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID)/events"
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
            guard let startDT = raw.start, !startDT.isAllDay,
                  let startTime = startDT.resolved,
                  let endTime = raw.end?.resolved else {
                return nil
            }
            guard raw.status != "cancelled" else { return nil }

            let otherAttendees = (raw.attendees ?? []).filter { $0.isSelf != true }

            return CalendarEvent(
                id: raw.id,
                summary: raw.summary ?? "(No title)",
                startTime: startTime,
                endTime: endTime,
                hasOtherAttendees: !otherAttendees.isEmpty
            )
        }
    }

    func fetchCalendars(accessToken: String) async throws -> [CalendarInfo] {
        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse

        guard http.statusCode != 401 else {
            throw CalendarClientError.unauthorised
        }
        guard http.statusCode == 200 else {
            throw CalendarClientError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(CalendarListResponse.self, from: data)
        let items = decoded.items ?? []

        return items.map { raw in
            CalendarInfo(
                id: raw.id,
                summary: raw.summary ?? "(No name)",
                backgroundColor: raw.backgroundColor ?? "#888888"
            )
        }
    }
}
