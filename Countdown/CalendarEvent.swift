// ABOUTME: Decodable models for Google Calendar API responses.
// ABOUTME: Covers calendar list entries, event details, and attendee presence.

import Foundation

struct CalendarEventList: Decodable {
    let items: [RawCalendarEvent]?
}

struct RawCalendarEvent: Decodable {
    let id: String
    let summary: String?
    let status: String?
    let eventType: String?
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
    let endTime: Date
    let hasOtherAttendees: Bool
    let eventType: String?

    init(
        id: String,
        summary: String,
        startTime: Date,
        endTime: Date,
        hasOtherAttendees: Bool,
        eventType: String? = nil
    ) {
        self.id = id
        self.summary = summary
        self.startTime = startTime
        self.endTime = endTime
        self.hasOtherAttendees = hasOtherAttendees
        self.eventType = eventType
    }
}

struct CalendarListResponse: Decodable {
    let items: [RawCalendarInfo]?
}

struct RawCalendarInfo: Decodable {
    let id: String
    let summary: String?
    let backgroundColor: String?
}

struct CalendarInfo: Identifiable, Equatable {
    let id: String
    let summary: String
    let backgroundColor: String
}
