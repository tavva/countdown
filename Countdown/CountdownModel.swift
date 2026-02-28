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

    var alwaysShowCircle: Bool {
        get {
            if UserDefaults.standard.object(forKey: "alwaysShowCircle") == nil { return true }
            return UserDefaults.standard.bool(forKey: "alwaysShowCircle")
        }
        set { UserDefaults.standard.set(newValue, forKey: "alwaysShowCircle") }
    }

    private(set) var shouldShowOverlay: Bool = false
    private(set) var minutesRemaining: Int = 0
    private(set) var colourProgress: Double = 0.0  // 0 = green (60 min), 1 = red (0 min)
    private(set) var isFlashing: Bool = false
    private(set) var isIdle: Bool = false
    private(set) var meetingRingProgress: Double = 0.0  // 0 = no ring, 1 = full ring
    var showingEventDetails: Bool {
        get {
            if UserDefaults.standard.object(forKey: "showingEventDetails") == nil { return true }
            return UserDefaults.standard.bool(forKey: "showingEventDetails")
        }
        set { UserDefaults.standard.set(newValue, forKey: "showingEventDetails") }
    }

    private var dismissedEventID: String?

    func setEvents(_ events: [CalendarEvent]) {
        nextEvent = events.first { $0.endTime.timeIntervalSinceNow > 0 }
    }

    func toggleEventDetails() {
        showingEventDetails.toggle()
    }

    func updateState() {
        guard let event = nextEvent else {
            setIdleOrHidden()
            return
        }

        if meetingsOnly && !event.hasOtherAttendees {
            setIdleOrHidden()
            return
        }

        if event.id == dismissedEventID {
            setIdleOrHidden()
            return
        }

        let secondsUntilStart = event.startTime.timeIntervalSinceNow
        let minutesUntil = secondsUntilStart / 60.0
        let secondsUntilEnd = event.endTime.timeIntervalSinceNow

        if minutesUntil > 60 {
            setIdleOrHidden()
            return
        }

        if secondsUntilEnd <= 0 {
            setIdleOrHidden()
            return
        }

        shouldShowOverlay = true
        isIdle = false

        if minutesUntil <= 0 {
            // Meeting in progress — show remaining time and ring
            let totalDuration = event.endTime.timeIntervalSince(event.startTime)
            meetingRingProgress = totalDuration > 0 ? secondsUntilEnd / totalDuration : 0
            minutesRemaining = Int(ceil(secondsUntilEnd / 60.0))
            colourProgress = 1.0
            isFlashing = minutesUntil >= -5
        } else {
            // Counting down to meeting start
            meetingRingProgress = 0
            minutesRemaining = Int(ceil(minutesUntil))
            colourProgress = min(1.0, max(0.0, 1.0 - (minutesUntil / 60.0)))
            isFlashing = minutesUntil < 1
        }
    }

    private func setIdleOrHidden() {
        meetingRingProgress = 0
        if alwaysShowCircle {
            shouldShowOverlay = true
            isIdle = true
            isFlashing = false
        } else {
            shouldShowOverlay = false
            isIdle = false
        }
    }

    func dismiss() {
        dismissedEventID = nextEvent?.id
        shouldShowOverlay = false
        isFlashing = false
    }
}
