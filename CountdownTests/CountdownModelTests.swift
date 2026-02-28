// ABOUTME: Tests for the countdown model's time-based colour and flash logic.
// ABOUTME: Verifies state transitions based on minutes remaining until an event.

import Testing
import Foundation
@testable import Countdown

@Suite("CountdownModel", .serialized)
struct CountdownModelTests {
    @Test func noEventShowsIdleWhenAlwaysShowCircle() {
        let model = CountdownModel()
        model.alwaysShowCircle = true
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == true)
        #expect(model.isFlashing == false)
    }

    @Test func noEventHiddenWhenNotAlwaysShowCircle() {
        let model = CountdownModel()
        model.alwaysShowCircle = false
        model.updateState()
        #expect(model.shouldShowOverlay == false)
        #expect(model.isIdle == false)
    }

    @Test func eventWithinWindowClearsIdleState() {
        let model = CountdownModel()
        model.alwaysShowCircle = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == false)
    }

    @Test func filteredEventShowsIdleWhenAlwaysShowCircle() {
        let model = CountdownModel()
        model.alwaysShowCircle = true
        model.meetingsOnly = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus Time",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == true)
    }

    @Test func alwaysShowCircleDefaultsToTrue() {
        UserDefaults.standard.removeObject(forKey: "alwaysShowCircle")
        let model = CountdownModel()
        #expect(model.alwaysShowCircle == true)
    }

    @Test func eventWithin60MinutesShowsOverlay() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.minutesRemaining == 30)
    }

    @Test func colourIsGreenAt60Minutes() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(60 * 60),
            endTime: Date().addingTimeInterval(90 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.colourProgress < 0.05)
    }

    @Test func colourIsRedAt1Minute() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(60),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.colourProgress > 0.95)
    }

    @Test func flashesWithin1Minute() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isFlashing == true)
    }

    @Test func flashesDuringFirst5MinutesAfterStart() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-3 * 60),
            endTime: Date().addingTimeInterval(27 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isFlashing == true)
        #expect(model.minutesRemaining == 27)
    }

    @Test func stopsFlashingAfter5MinutesPastStart() {
        let model = CountdownModel()
        model.alwaysShowCircle = false
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-6 * 60),
            endTime: Date().addingTimeInterval(24 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isFlashing == false)
        #expect(model.meetingRingProgress > 0.7)
    }

    @Test func clickDismissesCurrentEvent() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "evt-1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isFlashing == true)

        model.dismiss()
        #expect(model.shouldShowOverlay == false)
    }

    @Test func meetingsOnlyFilterExcludesSoloEvents() {
        let model = CountdownModel()
        model.alwaysShowCircle = false
        model.meetingsOnly = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus Time",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false
        )
        model.updateState()
        #expect(model.shouldShowOverlay == false)
    }

    @Test func meetingsOnlyFilterIncludesMeetings() {
        let model = CountdownModel()
        model.meetingsOnly = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
    }

    @Test func showsInProgressMeetingOverUpcoming() {
        let model = CountdownModel()
        model.setEvents([
            CalendarEvent(
                id: "current",
                summary: "Current Meeting",
                startTime: Date().addingTimeInterval(-10 * 60),
                endTime: Date().addingTimeInterval(20 * 60),
                hasOtherAttendees: true
            ),
            CalendarEvent(
                id: "upcoming",
                summary: "Next Meeting",
                startTime: Date().addingTimeInterval(20 * 60),
                endTime: Date().addingTimeInterval(50 * 60),
                hasOtherAttendees: true
            ),
        ])
        model.updateState()
        #expect(model.nextEvent?.id == "current")
        #expect(model.shouldShowOverlay == true)
        #expect(model.meetingRingProgress > 0.5)
    }

    @Test func skipsEndedEventShowsUpcoming() {
        let model = CountdownModel()
        model.setEvents([
            CalendarEvent(
                id: "ended",
                summary: "Old Meeting",
                startTime: Date().addingTimeInterval(-60 * 60),
                endTime: Date().addingTimeInterval(-10 * 60),
                hasOtherAttendees: true
            ),
            CalendarEvent(
                id: "upcoming",
                summary: "Next Meeting",
                startTime: Date().addingTimeInterval(20 * 60),
                endTime: Date().addingTimeInterval(50 * 60),
                hasOtherAttendees: true
            ),
        ])
        model.updateState()
        #expect(model.nextEvent?.id == "upcoming")
        #expect(model.shouldShowOverlay == true)
    }

    @Test func showingEventDetailsDefaultsToTrue() {
        UserDefaults.standard.removeObject(forKey: "showingEventDetails")
        let model = CountdownModel()
        #expect(model.showingEventDetails == true)
    }

    @Test func toggleEventDetailsPersists() {
        let model = CountdownModel()
        model.showingEventDetails = true
        model.toggleEventDetails()
        #expect(model.showingEventDetails == false)

        let model2 = CountdownModel()
        #expect(model2.showingEventDetails == false)

        model2.toggleEventDetails()
        #expect(model2.showingEventDetails == true)
    }

    @Test func showingEventDetailsSurvivesEventChange() {
        let model = CountdownModel()
        model.showingEventDetails = false

        model.setEvents([CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )])
        #expect(model.showingEventDetails == false)

        model.setEvents([CalendarEvent(
            id: "2",
            summary: "Other meeting",
            startTime: Date().addingTimeInterval(20 * 60),
            endTime: Date().addingTimeInterval(50 * 60),
            hasOtherAttendees: true
        )])
        #expect(model.showingEventDetails == false)

        // Restore default
        model.showingEventDetails = true
    }

    @Test func showingEventDetailsSurvivesDismiss() {
        let model = CountdownModel()
        model.showingEventDetails = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()

        model.dismiss()
        #expect(model.showingEventDetails == true)
    }

    @Test func allEventsShowsSoloEvents() {
        let model = CountdownModel()
        model.meetingsOnly = false
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus Time",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
    }

    // MARK: - Meeting ring progress

    @Test func meetingRingProgressIsZeroBeforeMeetingStarts() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.meetingRingProgress == 0.0)
    }

    @Test func meetingRingProgressAtMeetingMidpoint() {
        let model = CountdownModel()
        // 60-min meeting, 30 min in → 50% remaining
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-30 * 60),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.meetingRingProgress > 0.45)
        #expect(model.meetingRingProgress < 0.55)
    }

    @Test func meetingRingProgressNearStart() {
        let model = CountdownModel()
        // 60-min meeting, 1 min in → ~98% remaining
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-1 * 60),
            endTime: Date().addingTimeInterval(59 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.meetingRingProgress > 0.95)
    }

    @Test func meetingRingProgressNearEnd() {
        let model = CountdownModel()
        // 60-min meeting, 58 min in → ~3% remaining
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-58 * 60),
            endTime: Date().addingTimeInterval(2 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.meetingRingProgress < 0.05)
        #expect(model.meetingRingProgress > 0.0)
    }

    @Test func meetingRingProgressIsZeroAfterMeetingEnds() {
        let model = CountdownModel()
        model.alwaysShowCircle = false
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-60 * 60),
            endTime: Date().addingTimeInterval(-1 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.meetingRingProgress == 0.0)
        #expect(model.shouldShowOverlay == false)
    }

    @Test func minutesRemainingShowsMeetingTimeLeftDuringMeeting() {
        let model = CountdownModel()
        // 60-min meeting, 15 min in → 45 min remaining
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-15 * 60),
            endTime: Date().addingTimeInterval(45 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.minutesRemaining == 45)
    }

    @Test func overlayVisibleDuringEntireMeeting() {
        let model = CountdownModel()
        model.alwaysShowCircle = false
        // 60-min meeting, 30 min in
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-30 * 60),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isFlashing == false)
    }
}
