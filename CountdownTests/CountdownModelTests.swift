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
        #expect(model.minutesRemaining == 0)
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
        #expect(model.shouldShowOverlay == false)
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

    @Test func skipsEventPastDisplayWindow() {
        let model = CountdownModel()
        model.setEvents([
            CalendarEvent(
                id: "past",
                summary: "Old Meeting",
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
        #expect(model.nextEvent?.id == "upcoming")
        #expect(model.shouldShowOverlay == true)
    }

    @Test func toggleEventDetailsFlipsState() {
        let model = CountdownModel()
        #expect(model.showingEventDetails == false)
        model.toggleEventDetails()
        #expect(model.showingEventDetails == true)
        model.toggleEventDetails()
        #expect(model.showingEventDetails == false)
    }

    @Test func eventDetailsResetWhenEventChanges() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        model.toggleEventDetails()
        #expect(model.showingEventDetails == true)

        model.setEvents([CalendarEvent(
            id: "2",
            summary: "Other meeting",
            startTime: Date().addingTimeInterval(20 * 60),
            endTime: Date().addingTimeInterval(50 * 60),
            hasOtherAttendees: true
        )])
        #expect(model.showingEventDetails == false)
    }

    @Test func eventDetailsResetWhenDismissed() {
        let model = CountdownModel()
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        model.toggleEventDetails()
        #expect(model.showingEventDetails == true)

        model.dismiss()
        #expect(model.showingEventDetails == false)
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
}
