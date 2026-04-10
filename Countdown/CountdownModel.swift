// ABOUTME: Central model tracking the next calendar event and countdown display state.
// ABOUTME: Computes colour, flash state, and visibility based on time remaining.

import Foundation
import Observation

enum SizeMode: Int {
    case standard = 0
    case compact = 1
    case auto = 2
}

enum ScreenCorner: Int {
    case topLeft = 0
    case topRight = 1
    case bottomLeft = 2
    case bottomRight = 3
}

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
    /// When true, filters out non-meeting Google Calendar event types
    /// (tasks, birthdays, out-of-office, working location, Gmail-extracted
    /// events). Keeps `default` and `focusTime` events.
    var hideTasksAndBirthdays: Bool {
        didSet { defaults.set(hideTasksAndBirthdays, forKey: DefaultsKey.hideTasksAndBirthdays) }
    }

    private(set) var shouldShowOverlay: Bool = true
    private(set) var minutesRemaining: Int = 0
    private(set) var colourProgress: Double = 0.0  // 0 = green (60 min), 1 = red (0 min)
    private(set) var isFlashing: Bool = false
    private(set) var isIdle: Bool = false
    private(set) var isLoading: Bool = true
    private(set) var ringProgress: Double = 0.0  // 0 = no ring, 1 = full ring
    // Effective state — derived from sizeMode + current display configuration.
    // Production code should route changes through sizeMode or applyEffectiveMode;
    // tests may set it directly to exercise layout logic.
    var compactMode: Bool = false

    var sizeMode: SizeMode {
        didSet {
            defaults.set(sizeMode.rawValue, forKey: DefaultsKey.sizeMode)
            switch sizeMode {
            case .standard: compactMode = false
            case .compact: compactMode = true
            case .auto: break  // AppDelegate calls applyEffectiveMode via observation
            }
        }
    }

    var autoReposition: Bool {
        didSet { defaults.set(autoReposition, forKey: DefaultsKey.autoReposition) }
    }

    var repositionCorner: ScreenCorner {
        didSet { defaults.set(repositionCorner.rawValue, forKey: DefaultsKey.repositionCorner) }
    }

    var showingEventDetails: Bool {
        didSet { defaults.set(showingEventDetails, forKey: DefaultsKey.showingEventDetails) }
    }

    static let nonMeetingEventTypes: Set<String> = [
        "task", "birthday", "fromGmail", "outOfOffice", "workingLocation",
    ]

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

        self.hideTasksAndBirthdays = defaults.bool(forKey: DefaultsKey.hideTasksAndBirthdays)

        // Migrate: if sizeMode isn't set but legacy compactMode is, derive sizeMode from it.
        let resolvedMode: SizeMode
        if defaults.object(forKey: DefaultsKey.sizeMode) != nil {
            resolvedMode = SizeMode(rawValue: defaults.integer(forKey: DefaultsKey.sizeMode)) ?? .standard
        } else if defaults.object(forKey: DefaultsKey.compactMode) != nil {
            resolvedMode = defaults.bool(forKey: DefaultsKey.compactMode) ? .compact : .standard
        } else {
            resolvedMode = .standard
        }
        self.sizeMode = resolvedMode
        // Persist migrated value so the didSet-free init path still writes it.
        defaults.set(resolvedMode.rawValue, forKey: DefaultsKey.sizeMode)

        self.autoReposition = defaults.bool(forKey: DefaultsKey.autoReposition)
        self.repositionCorner = ScreenCorner(rawValue: defaults.integer(forKey: DefaultsKey.repositionCorner)) ?? .topLeft

        // Set initial compactMode to match non-auto sizeMode. Auto mode is applied
        // by AppDelegate after init once NSScreen is available.
        switch resolvedMode {
        case .standard: self.compactMode = false
        case .compact: self.compactMode = true
        case .auto: self.compactMode = false  // placeholder, replaced on applyEffectiveMode
        }

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
        if compactMode {
            sizeMode = .standard
            compactMode = false
        } else {
            sizeMode = .compact
            compactMode = true
        }
    }

    func applyEffectiveMode(hasExternalDisplay: Bool) {
        let newValue: Bool
        switch sizeMode {
        case .standard: newValue = false
        case .compact: newValue = true
        case .auto: newValue = !hasExternalDisplay
        }
        if compactMode != newValue {
            compactMode = newValue
        }
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

        if hideTasksAndBirthdays && CountdownModel.nonMeetingEventTypes.contains(event.eventType ?? "") {
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
    static let hideTasksAndBirthdays = "hideTasksAndBirthdays"
    static let compactMode = "compactMode"
    static let showingEventDetails = "showingEventDetails"
    static let sizeMode = "sizeMode"
    static let autoReposition = "autoReposition"
    static let repositionCorner = "repositionCorner"
}
