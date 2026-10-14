// ABOUTME: Tests for the wording used when hiding the overlay until a chosen time.
// ABOUTME: Covers the right-click menu title and the popover's "Hidden until" description.

import Testing
import Foundation
@testable import Countdown

@Suite("HideUntilText")
struct HideUntilTextTests {
    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func menuTitleSaysTomorrowAfterFourAM() {
        let now = Self.date(2026, 10, 14, 15, 30)
        #expect(HideUntilText.fourAMMenuTitle(now: now) == "Hide Countdown until tomorrow, 4am")
    }

    @Test func menuTitleDropsTomorrowBeforeFourAM() {
        let now = Self.date(2026, 10, 14, 1, 15)
        #expect(HideUntilText.fourAMMenuTitle(now: now) == "Hide Countdown until 4am")
    }

    @Test func descriptionForToday() {
        let now = Self.date(2026, 10, 14, 1, 15)
        let until = Self.date(2026, 10, 14, 4)
        #expect(HideUntilText.hiddenUntil(until, now: now) == "Hidden until today 04:00")
    }

    @Test func descriptionForTomorrow() {
        let now = Self.date(2026, 10, 14, 15, 30)
        let until = Self.date(2026, 10, 15, 4)
        #expect(HideUntilText.hiddenUntil(until, now: now) == "Hidden until tomorrow 04:00")
    }

    @Test func descriptionForLaterDayUsesWeekdayAndDate() {
        let now = Self.date(2026, 10, 14, 15, 30)
        let until = Self.date(2026, 10, 17, 9, 30)
        #expect(HideUntilText.hiddenUntil(until, now: now) == "Hidden until Sat 17 Oct 09:30")
    }
}
