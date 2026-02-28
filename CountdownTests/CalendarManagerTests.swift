// ABOUTME: Tests for CalendarManager settings changes triggering immediate state updates.
// ABOUTME: Verifies that toggling meetingsOnly instantly updates the model's display state.

import Testing
import Foundation
@testable import Countdown

@Suite("CalendarManager")
struct CalendarManagerTests {
    @Test @MainActor func setMeetingsOnlyUpdatesOverlayImmediately() {
        let manager = CalendarManager()
        manager.model.alwaysShowCircle = false
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

        manager.setMeetingsOnly(true)

        #expect(manager.model.meetingsOnly == true)
        #expect(manager.model.shouldShowOverlay == false)
    }

    @Test @MainActor func setMeetingsOnlyToFalseShowsSoloEvents() {
        let manager = CalendarManager()
        manager.model.alwaysShowCircle = false
        manager.model.meetingsOnly = true
        manager.model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus Time",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false
        )
        manager.model.updateState()
        #expect(manager.model.shouldShowOverlay == false)

        manager.setMeetingsOnly(false)

        #expect(manager.model.meetingsOnly == false)
        #expect(manager.model.shouldShowOverlay == true)
    }
}
