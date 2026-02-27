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

struct CalendarEvent {
    let id: String
    let summary: String
    let startTime: Date
    let hasOtherAttendees: Bool
}
