// ABOUTME: Tests for the countdown model's time-based colour and flash logic.
// ABOUTME: Verifies state transitions based on minutes remaining until an event.

import Testing
import Foundation
@testable import Countdown

@Suite("CountdownModel", .serialized)
struct CountdownModelTests {
    private let _snapshot = DefaultsSnapshot(keys: [
        "meetingsOnly", "showingEventDetails", "compactMode",
        "hideDeclinedEvents", "sizeMode", "autoReposition", "repositionCorner",
        "hideTasksAndBirthdays",
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

    @Test func updateStateDuringLoadingKeepsLoadingVisible() {
        let model = CountdownModel()
        model.updateState()
        #expect(model.isLoading == true)
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == false)
    }

    // MARK: - Idle state

    @Test func noEventShowsIdle() {
        let model = CountdownModel()
        model.setEvents([])
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == true)
        #expect(model.isFlashing == false)
    }

    @Test func eventWithinWindowClearsIdleState() {
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
        #expect(model.isIdle == false)
    }

    @Test func filteredEventShowsIdle() {
        let model = CountdownModel()
        model.setEvents([])
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
        model.updateState()
        #expect(model.displayedEvent == nil)
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

    @Test func idlesAfter5MinutesPastStart() {
        let model = CountdownModel()
        model.setEvents([])
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Meeting",
            startTime: Date().addingTimeInterval(-6 * 60),
            endTime: Date().addingTimeInterval(24 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == true)
        #expect(model.isFlashing == false)
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

    @Test func showingEventDetailsChangesAreObservable() {
        let model = CountdownModel()
        let changes = ChangeBox()

        withObservationTracking {
            _ = model.showingEventDetails
        } onChange: {
            changes.value += 1
        }

        model.toggleEventDetails()
        #expect(changes.value == 1)
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

        model.updateState()
        #expect(model.ringProgress == 0.0)
    }

    // MARK: - Empty message

    @Test func showsEmptyMessageWhenIdleWithDetailsOn() {
        let model = CountdownModel()
        model.setEvents([])

        model.showingEventDetails = true
        model.updateState()
        #expect(model.shouldShowEmptyMessage == true)
    }

    @Test func hidesEmptyMessageWhenDetailsOff() {
        let model = CountdownModel()
        model.setEvents([])

        model.showingEventDetails = false
        model.updateState()
        #expect(model.shouldShowEmptyMessage == false)
    }

    @Test func hidesEmptyMessageWhenEventActive() {
        let model = CountdownModel()
        model.setEvents([])
        model.showingEventDetails = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowEmptyMessage == false)
    }

    @Test func hidesEmptyMessageWhileLoading() {
        let model = CountdownModel()
        model.showingEventDetails = true
        #expect(model.isLoading == true)
        #expect(model.shouldShowEmptyMessage == false)
    }

    // MARK: - Compact mode

    @Test func compactModeDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: "compactMode")
        UserDefaults.standard.removeObject(forKey: "sizeMode")
        let model = CountdownModel()
        #expect(model.compactMode == false)
    }

    @Test func toggleCompactMode() {
        let model = CountdownModel()
        model.sizeMode = .standard  // ensures compactMode == false
        model.toggleCompactMode()
        #expect(model.compactMode == true)
        #expect(model.sizeMode == .compact)
        model.toggleCompactMode()
        #expect(model.compactMode == false)
        #expect(model.sizeMode == .standard)
    }

    @Test func compactModeChangesAreObservable() {
        let model = CountdownModel()
        let changes = ChangeBox()

        withObservationTracking {
            _ = model.compactMode
        } onChange: {
            changes.value += 1
        }

        model.toggleCompactMode()
        #expect(changes.value == 1)
    }

    // MARK: - Hide declined events

    @Test func hideDeclinedEventsDefaultsToTrue() {
        UserDefaults.standard.removeObject(forKey: "hideDeclinedEvents")
        let model = CountdownModel()
        #expect(model.hideDeclinedEvents == true)
    }

    @Test func hideDeclinedEventsFiltersDeclinedPrefix() {
        let model = CountdownModel()
        model.setEvents([])
        model.hideDeclinedEvents = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Declined: Team Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == true)
    }

    @Test func hideDeclinedEventsFiltersCancelledPrefix() {
        let model = CountdownModel()
        model.setEvents([])
        model.hideDeclinedEvents = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Cancelled: Sprint Review",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == true)
    }

    @Test func hideDeclinedEventsOffShowsDeclinedEvents() {
        let model = CountdownModel()
        model.setEvents([])
        model.hideDeclinedEvents = false
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Declined: Team Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == false)
    }

    @Test func hideDeclinedEventsPersists() {
        let model = CountdownModel()
        model.hideDeclinedEvents = false
        #expect(model.hideDeclinedEvents == false)

        let model2 = CountdownModel()
        #expect(model2.hideDeclinedEvents == false)
    }

    // MARK: - Hide tasks and birthdays

    @Test func hideTasksAndBirthdaysDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: "hideTasksAndBirthdays")
        let model = CountdownModel()
        #expect(model.hideTasksAndBirthdays == false)
    }

    @Test func hideTasksAndBirthdaysPersists() {
        let model = CountdownModel()
        model.hideTasksAndBirthdays = true
        #expect(model.hideTasksAndBirthdays == true)

        let model2 = CountdownModel()
        #expect(model2.hideTasksAndBirthdays == true)
    }

    @Test func hideTasksAndBirthdaysFiltersTaskEventType() {
        let model = CountdownModel()
        model.setEvents([])
        model.hideTasksAndBirthdays = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Buy milk",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false,
            eventType: "task"
        )
        model.updateState()
        #expect(model.shouldShowOverlay == true)
        #expect(model.isIdle == true)
    }

    @Test func hideTasksAndBirthdaysFiltersBirthdayEventType() {
        let model = CountdownModel()
        model.setEvents([])
        model.hideTasksAndBirthdays = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Alice's birthday",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false,
            eventType: "birthday"
        )
        model.updateState()
        #expect(model.isIdle == true)
    }

    @Test func hideTasksAndBirthdaysFiltersOutOfOfficeFromGmailWorkingLocation() {
        let model = CountdownModel()
        model.setEvents([])
        model.hideTasksAndBirthdays = true

        for type in ["outOfOffice", "fromGmail", "workingLocation"] {
            model.nextEvent = CalendarEvent(
                id: type,
                summary: "Auto event",
                startTime: Date().addingTimeInterval(30 * 60),
                endTime: Date().addingTimeInterval(60 * 60),
                hasOtherAttendees: false,
                eventType: type
            )
            model.updateState()
            #expect(model.isIdle == true, "Expected \(type) to be filtered")
        }
    }

    @Test func hideTasksAndBirthdaysKeepsDefaultEventType() {
        let model = CountdownModel()
        model.setEvents([])
        model.hideTasksAndBirthdays = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Standup",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true,
            eventType: "default"
        )
        model.updateState()
        #expect(model.isIdle == false)
    }

    @Test func hideTasksAndBirthdaysKeepsFocusTime() {
        let model = CountdownModel()
        model.setEvents([])
        model.meetingsOnly = false
        model.hideTasksAndBirthdays = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Focus block",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false,
            eventType: "focusTime"
        )
        model.updateState()
        #expect(model.isIdle == false)
    }

    @Test func hideTasksAndBirthdaysKeepsNilEventType() {
        let model = CountdownModel()
        model.setEvents([])
        model.hideTasksAndBirthdays = true
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Legacy event",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: true,
            eventType: nil
        )
        model.updateState()
        #expect(model.isIdle == false)
    }

    @Test func hideTasksAndBirthdaysOffShowsTaskEvents() {
        let model = CountdownModel()
        model.setEvents([])
        model.meetingsOnly = false
        model.hideTasksAndBirthdays = false
        model.nextEvent = CalendarEvent(
            id: "1",
            summary: "Buy milk",
            startTime: Date().addingTimeInterval(30 * 60),
            endTime: Date().addingTimeInterval(60 * 60),
            hasOtherAttendees: false,
            eventType: "task"
        )
        model.updateState()
        #expect(model.isIdle == false)
    }

    // MARK: - Size mode

    @Test func sizeModeDefaultsToStandardWhenNothingPersisted() {
        UserDefaults.standard.removeObject(forKey: "sizeMode")
        UserDefaults.standard.removeObject(forKey: "compactMode")
        let model = CountdownModel()
        #expect(model.sizeMode == .standard)
    }

    @Test func sizeModeMigratesFromLegacyCompactModeTrue() {
        UserDefaults.standard.removeObject(forKey: "sizeMode")
        UserDefaults.standard.set(true, forKey: "compactMode")
        let model = CountdownModel()
        #expect(model.sizeMode == .compact)
    }

    @Test func sizeModeMigratesFromLegacyCompactModeFalse() {
        UserDefaults.standard.removeObject(forKey: "sizeMode")
        UserDefaults.standard.set(false, forKey: "compactMode")
        let model = CountdownModel()
        #expect(model.sizeMode == .standard)
    }

    @Test func sizeModePersists() {
        let model = CountdownModel()
        model.sizeMode = .auto
        let model2 = CountdownModel()
        #expect(model2.sizeMode == .auto)
    }

    @Test func applyEffectiveModeStandard() {
        let model = CountdownModel()
        model.sizeMode = .standard
        model.applyEffectiveMode(hasExternalDisplay: false)
        #expect(model.compactMode == false)
        model.applyEffectiveMode(hasExternalDisplay: true)
        #expect(model.compactMode == false)
    }

    @Test func applyEffectiveModeCompact() {
        let model = CountdownModel()
        model.sizeMode = .compact
        model.applyEffectiveMode(hasExternalDisplay: false)
        #expect(model.compactMode == true)
        model.applyEffectiveMode(hasExternalDisplay: true)
        #expect(model.compactMode == true)
    }

    @Test func applyEffectiveModeAutoWithoutExternalUsesCompact() {
        let model = CountdownModel()
        model.sizeMode = .auto
        model.applyEffectiveMode(hasExternalDisplay: false)
        #expect(model.compactMode == true)
    }

    @Test func applyEffectiveModeAutoWithExternalUsesStandard() {
        let model = CountdownModel()
        model.sizeMode = .auto
        model.applyEffectiveMode(hasExternalDisplay: true)
        #expect(model.compactMode == false)
    }

    // MARK: - Auto reposition

    @Test func autoRepositionDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: "autoReposition")
        let model = CountdownModel()
        #expect(model.autoReposition == false)
    }

    @Test func autoRepositionPersists() {
        let model = CountdownModel()
        model.autoReposition = true
        let model2 = CountdownModel()
        #expect(model2.autoReposition == true)
    }

    @Test func repositionCornerDefaultsToTopLeft() {
        UserDefaults.standard.removeObject(forKey: "repositionCorner")
        let model = CountdownModel()
        #expect(model.repositionCorner == .topLeft)
    }

    @Test func repositionCornerPersists() {
        let model = CountdownModel()
        model.repositionCorner = .bottomRight
        let model2 = CountdownModel()
        #expect(model2.repositionCorner == .bottomRight)
    }

    // MARK: - Context menu toggle respects sizeMode

    @Test func toggleCompactModeUpdatesSizeMode() {
        let model = CountdownModel()
        model.sizeMode = .auto
        model.applyEffectiveMode(hasExternalDisplay: true)  // compactMode=false
        model.toggleCompactMode()
        #expect(model.sizeMode == .compact)
        #expect(model.compactMode == true)
        model.toggleCompactMode()
        #expect(model.sizeMode == .standard)
        #expect(model.compactMode == false)
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

final class ChangeBox: @unchecked Sendable {
    var value: Int = 0
}
