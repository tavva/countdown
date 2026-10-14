// ABOUTME: Wording for hiding the overlay until a chosen time.
// ABOUTME: Builds the right-click menu title and the popover's "Hidden until" line.

import Foundation

enum HideUntilText {
    /// "Hide Countdown until tomorrow, 4am", or "Hide Countdown until 4am" when the next 4am is
    /// later today (between midnight and 4am).
    static func fourAMMenuTitle(now: Date = Date(), calendar: Calendar = .current) -> String {
        let fourAM = CountdownModel.nextFourAM(after: now, calendar: calendar)
        return calendar.isDate(fourAM, inSameDayAs: now) ? "Hide Countdown until 4am" : "Hide Countdown until tomorrow, 4am"
    }

    /// "Hidden until today 04:00", "Hidden until tomorrow 04:00", or with the
    /// weekday and date for anything further off, e.g. "Hidden until Sat 17 Oct 09:30".
    static func hiddenUntil(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: date)

        let day: String
        if calendar.isDate(date, inSameDayAs: now) {
            day = "today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(date, inSameDayAs: tomorrow) {
            day = "tomorrow"
        } else {
            formatter.dateFormat = "EEE d MMM"
            day = formatter.string(from: date)
        }
        return "Hidden until \(day) \(time)"
    }
}
