// ABOUTME: Central model tracking the next calendar event and countdown display state.
// ABOUTME: Computes colour, flash state, and visibility based on time remaining.

import Foundation
import Observation

@Observable
final class CountdownModel {
    var nextEvent: CalendarEvent?
    var meetingsOnly: Bool {
        get { UserDefaults.standard.bool(forKey: "meetingsOnly") }
        set { UserDefaults.standard.set(newValue, forKey: "meetingsOnly") }
    }

    private(set) var shouldShowOverlay: Bool = false
    private(set) var minutesRemaining: Int = 0
    private(set) var colourProgress: Double = 0.0  // 0 = green (60 min), 1 = red (0 min)
    private(set) var isFlashing: Bool = false
    private(set) var showingEventDetails: Bool = false

    private var dismissedEventID: String?

    func setEvents(_ events: [CalendarEvent]) {
        let newEvent = events.first { $0.startTime.timeIntervalSinceNow >= -5 * 60 }
        if newEvent?.id != nextEvent?.id {
            showingEventDetails = false
        }
        nextEvent = newEvent
    }

    func toggleEventDetails() {
        showingEventDetails.toggle()
    }

    func updateState() {
        guard let event = nextEvent else {
            shouldShowOverlay = false
            return
        }

        if meetingsOnly && !event.hasOtherAttendees {
            shouldShowOverlay = false
            return
        }

        if event.id == dismissedEventID {
            shouldShowOverlay = false
            return
        }

        let secondsUntilStart = event.startTime.timeIntervalSinceNow
        let minutesUntil = secondsUntilStart / 60.0

        if minutesUntil > 60 {
            shouldShowOverlay = false
            return
        }

        if minutesUntil < -5 {
            shouldShowOverlay = false
            return
        }

        shouldShowOverlay = true
        minutesRemaining = max(0, Int(ceil(minutesUntil)))

        if minutesUntil > 0 {
            colourProgress = 1.0 - (minutesUntil / 60.0)
        } else {
            colourProgress = 1.0
        }
        colourProgress = min(1.0, max(0.0, colourProgress))

        isFlashing = minutesUntil < 1 && minutesUntil >= -5
    }

    func dismiss() {
        dismissedEventID = nextEvent?.id
        shouldShowOverlay = false
        isFlashing = false
        showingEventDetails = false
    }
}
