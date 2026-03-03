// ABOUTME: Tests for the countdown model's time-based colour and flash logic.
// ABOUTME: Verifies state transitions based on minutes remaining until an event.

import Testing
import Foundation
@testable import Countdown

@Suite("CountdownModel", .serialized)
struct CountdownModelTests {
    private let _snapshot = DefaultsSnapshot(keys: [
        "meetingsOnly", "alwaysShowCircle", "showingEventDetails",
    ])

    // MARK: - Loading state

    @Test func startsInLoadingState() {
        let model = CountdownModel()
        #expect(model.isLoading == true)
        #expect(model.shouldShowOverlay == true)
    }

    @Test func loadingClearsAfterSetEvents() {
        let model = CountdownModel()
        model.setEvents([])
        #expect(model.isLoading == false)
    }

    @Test func loadingStateShowsOverlayRegardlessOfAlwaysShowCircle() {
        let model = CountdownModel()
        model.alwaysShowCircle = false
        #expect(model.isLoading == true)
        #expect(model.shouldShowOverlay == true)
    }

    @Test func updateStateDuringLoadingKeepsLoadingVisible() {
        let model = CountdownModel()
        model.updateState()
        #expect(model.isLoading == true)
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == false)
    }

    // MARK: - Idle state

    @Test func noEventShowsIdleWhenAlwaysShowCircle() {
        let model = CountdownModel()
        model.setEvents([])
        model.alwaysShowCircle = true
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == true)
        #expect(model.isFlashing == false)
    }

    @Test func noEventHiddenWhenNotAlwaysShowCircle() {
        let model = CountdownModel()
        model.setEvents([])
        model.alwaysShowCircle = false
        model.updateState()
        #expect(model.shouldShowOverlay == false)
        #expect(model.isIdle == false)
    }

    @Test func eventWithinWindowClearsIdleState() {
        let model = CountdownModel()
        model.setEvents([])
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
        model.setEvents([])
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

    @Test func displayedEventIsNilWhenFilteredByMeetingsOnly() {
        let model = CountdownModel()
        model.setEvents([])
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
        #expect(model.isIdle == true)
        #expect(model.displayedEvent == nil)
    }

    @Test func displayedEventIsSetForActiveEvent() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isIdle == false)
        #expect(model.displayedEvent?.id == "1")
    }

    @Test func displayedEventIsNilWhenNoEvents() {
        let model = CountdownModel()
        model.setEvents([])
        model.alwaysShowCircle = true
        model.updateState()
        #expect(model.displayedEvent == nil)
    }

    @Test func alwaysShowCircleDefaultsToTrue() {
        UserDefaults.standard.removeObject(forKey: "alwaysShowCircle")
        let model = CountdownModel()
        #expect(model.alwaysShowCircle == true)
    }

    @Test func eventWithin60MinutesShowsOverlay() {
        let model = CountdownModel()
        model.setEvents([])
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

    @Test func colourProgressCurvesGreenLonger() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        // At 30 min (halfway), progress should be well below 0.5 due to curve
        #expect(model.colourProgress < 0.3)
    }

    @Test func colourIsGreenAt60Minutes() {
        let model = CountdownModel()
        model.setEvents([])
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
        model.setEvents([])
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
        model.setEvents([])
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
        model.setEvents([])
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
        model.setEvents([])
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
        model.setEvents([])
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
        model.setEvents([])
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
        model.setEvents([])
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
    }

    @Test func showingEventDetailsSurvivesDismiss() {
        let model = CountdownModel()
        model.setEvents([])
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
        model.setEvents([])
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

    // MARK: - Flash acknowledgement

    @Test func acknowledgeFlashStopsFlashing() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "evt-1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isFlashing == true)

        model.acknowledgeFlash()
        #expect(model.isFlashing == false)
    }

    @Test func acknowledgedFlashStaysOffAcrossUpdates() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "evt-1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        model.acknowledgeFlash()

        // Simulate the next 1-second tick
        model.updateState()
        #expect(model.isFlashing == false)
        #expect(model.shouldShowOverlay == true)
    }

    @Test func flashAcknowledgementResetsForNewEvent() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "evt-1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        model.acknowledgeFlash()
        #expect(model.isFlashing == false)

        // Different event starts flashing
        model.nextEvent = CalendarEvent(
            id: "evt-2",
            summary: "Another Meeting",
            startTime: Date().addingTimeInterval(20),
            endTime: Date().addingTimeInterval(30 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.isFlashing == true)
    }

    // MARK: - Countdown ring progress

    @Test func ringProgressIsFullAt60Minutes() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(60 * 60),
            endTime: Date().addingTimeInterval(90 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.ringProgress > 0.95)
    }

    @Test func ringProgressIsHalfAt30Minutes() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.ringProgress > 0.45)
        #expect(model.ringProgress < 0.55)
    }

    @Test func ringProgressIsSmallAt5Minutes() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(5 * 60),
            endTime: Date().addingTimeInterval(35 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.ringProgress > 0.07)
        #expect(model.ringProgress < 0.10)
    }

    @Test func ringProgressIsZeroAfterStart() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-3 * 60),
            endTime: Date().addingTimeInterval(27 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.ringProgress == 0.0)
    }

    @Test func ringProgressIsZeroWhenIdle() {
        let model = CountdownModel()
        model.setEvents([])
        model.alwaysShowCircle = true
        model.updateState()
        #expect(model.ringProgress == 0.0)
    }
}

// MARK: - Test helper

/// Saves and restores UserDefaults keys to prevent test pollution.
/// Store as a property on test structs — deinit restores values when the struct goes out of scope.
final class DefaultsSnapshot {
    private let saved: [String: Any?]
    private let defaults: UserDefaults

    init(keys: [String], defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var saved: [String: Any?] = [:]
        for key in keys {
            saved[key] = defaults.object(forKey: key)
        }
        self.saved = saved
    }

    deinit {
        for (key, value) in saved {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
