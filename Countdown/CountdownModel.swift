// ABOUTME: Central model tracking the next calendar event and countdown display state.
// ABOUTME: Computes colour, flash state, and visibility based on time remaining.

import Foundation
import Observation

@Observable
final class CountdownModel {
    private let defaults: UserDefaults

    var nextEvent: CalendarEvent?
    var displayedEvent: CalendarEvent? { isIdle ? nil : nextEvent }
    var shouldShowEmptyMessage: Bool { isIdle && !isLoading && showingEventDetails }
    var meetingsOnly: Bool {
        didSet { defaults.set(meetingsOnly, forKey: DefaultsKey.meetingsOnly) }
    }
    var hideDeclinedEvents: Bool {
        didSet { defaults.set(hideDeclinedEvents, forKey: DefaultsKey.hideDeclinedEvents) }
    }

    private(set) var shouldShowOverlay: Bool = true
    private(set) var minutesRemaining: Int = 0
    private(set) var colourProgress: Double = 0.0  // 0 = green (60 min), 1 = red (0 min)
    private(set) var isFlashing: Bool = false
    private(set) var isIdle: Bool = false
    private(set) var isLoading: Bool = true
    private(set) var ringProgress: Double = 0.0  // 0 = no ring, 1 = full ring
    var compactMode: Bool {
        didSet { defaults.set(compactMode, forKey: DefaultsKey.compactMode) }
    }

    var showingEventDetails: Bool {
        didSet { defaults.set(showingEventDetails, forKey: DefaultsKey.showingEventDetails) }
    }

    private var dismissedEventID: String?
    private var flashAcknowledgedEventID: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.meetingsOnly = defaults.bool(forKey: DefaultsKey.meetingsOnly)
        if defaults.object(forKey: DefaultsKey.hideDeclinedEvents) == nil {
            self.hideDeclinedEvents = true
        } else {
            self.hideDeclinedEvents = defaults.bool(forKey: DefaultsKey.hideDeclinedEvents)
        }
        self.compactMode = defaults.bool(forKey: DefaultsKey.compactMode)
        if defaults.object(forKey: DefaultsKey.showingEventDetails) == nil {
            self.showingEventDetails = true
        } else {
            self.showingEventDetails = defaults.bool(forKey: DefaultsKey.showingEventDetails)
        }
    }

    func setEvents(_ events: [CalendarEvent]) {
        isLoading = false
        nextEvent = events.first { $0.startTime.timeIntervalSinceNow >= -5 * 60 }
    }

    func toggleCompactMode() {
        compactMode.toggle()
    }

    func toggleEventDetails() {
        showingEventDetails.toggle()
    }

    func acknowledgeFlash() {
        flashAcknowledgedEventID = nextEvent?.id
        isFlashing = false
    }

    func updateState() {
        if isLoading {
            shouldShowOverlay = true
            return
        }

        guard let event = nextEvent else {
            setIdleOrHidden()
            return
        }

        if meetingsOnly && !event.hasOtherAttendees {
            setIdleOrHidden()
            return
        }

        if hideDeclinedEvents && (event.summary.hasPrefix("Declined:") || event.summary.hasPrefix("Cancelled:")) {
            setIdleOrHidden()
            return
        }

        if event.id == dismissedEventID {
            setIdleOrHidden()
            return
        }

        let secondsUntilStart = event.startTime.timeIntervalSinceNow
        let minutesUntil = secondsUntilStart / 60.0

        if minutesUntil > 60 {
            setIdleOrHidden()
            return
        }

        if minutesUntil < -5 {
            setIdleOrHidden()
            return
        }

        shouldShowOverlay = true
        isIdle = false
        minutesRemaining = max(0, Int(ceil(minutesUntil)))
        ringProgress = max(0.0, minutesUntil / 60.0)

        if minutesUntil > 0 {
            let linear = 1.0 - (minutesUntil / 60.0)
            colourProgress = pow(linear, 2)
        } else {
            colourProgress = 1.0
        }
        colourProgress = min(1.0, max(0.0, colourProgress))

        let shouldFlash = minutesUntil < 1 && minutesUntil >= -5
        isFlashing = shouldFlash && flashAcknowledgedEventID != event.id
    }

    private func setIdleOrHidden() {
        ringProgress = 0
        shouldShowOverlay = true
        isIdle = true
        isFlashing = false
    }

    func dismiss() {
        dismissedEventID = nextEvent?.id
        shouldShowOverlay = false
        isFlashing = false
    }
}

private enum DefaultsKey {
    static let meetingsOnly = "meetingsOnly"
    static let hideDeclinedEvents = "hideDeclinedEvents"
    static let compactMode = "compactMode"
    static let showingEventDetails = "showingEventDetails"
}
