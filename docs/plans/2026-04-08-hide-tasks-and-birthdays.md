# Hide Tasks & Birthdays Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a user setting that hides Google Calendar entries which aren't real meetings or focus blocks (tasks, birthdays, Gmail-extracted events, out-of-office, working location), keeping `default` and `focusTime` event types visible.

**Architecture:** Plumb Google Calendar's `eventType` field through `RawCalendarEvent` → `CalendarEvent` → `CountdownModel`. Add a new `hideTasksAndBirthdays` boolean on `CountdownModel` (UserDefaults-backed, default false). Filter is enforced in two places, mirroring how `meetingsOnly` and `hideDeclinedEvents` work today: `CalendarManager.fetchEvents` pre-filters events at poll time so `nextEvent` selection skips hidden entries entirely, and `CountdownModel.updateState` re-checks so toggling the setting updates the overlay without waiting for the next 60-second poll. Add a SwiftUI toggle to `SettingsView.eventsSection` using the existing `inlineToggle` helper.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing framework (`@Suite`/`@Test`/`#expect`), `MockURLProtocol` for HTTP mocking. Tests use `.serialized` because they touch shared `UserDefaults` keys.

## Background — what `eventType` is

Google Calendar API v3 returns an `eventType` string field on each event. Documented values:

| Value             | Meaning                                                | Hide?         |
|-------------------|--------------------------------------------------------|---------------|
| `default`         | Regular calendar event (most user-created events)      | Keep          |
| `focusTime`       | Focus time block (Google's dedicated feature)          | Keep          |
| `task`            | Entry backed by Google Tasks                           | **Hide**      |
| `birthday`        | Annual birthday entry                                  | **Hide**      |
| `fromGmail`       | Auto-created from a Gmail email                        | **Hide**      |
| `outOfOffice`     | Out-of-office state                                    | **Hide**      |
| `workingLocation` | "Working from home/office" tag                         | **Hide**      |

The new setting hides everything in the "Hide" rows above. Events with `eventType == nil` (e.g. older API responses, future unknown types) are kept — denylist semantics, not allowlist, because we want to hide *known* fluff, not be defensive against unknowns.

## Design notes the executor needs to know

- **Filter independence.** The new setting is *separate* from "Meetings only" (`meetingsOnly`). "Meetings only" filters by `hasOtherAttendees`, which would also hide solo focus blocks the user wants to keep. The new filter is orthogonal — hiding by `eventType` regardless of attendees.
- **Default off.** Setting starts disabled to preserve current behaviour for existing users. They opt in.
- **Field name vs label.** The implementation field is `hideTasksAndBirthdays` and the UI label is "Hide tasks & birthdays". The name is honest about user intent (tasks and birthdays are the visible cases) even though under the hood it also hides `fromGmail`/`outOfOffice`/`workingLocation`. The full set is documented in a code comment on the property and held in a static `nonMeetingEventTypes` set on `CountdownModel`.
- **Backwards-compatible `CalendarEvent` init.** Existing tests construct `CalendarEvent` directly with positional args (search the tests for `CalendarEvent(` — there are many call sites). To avoid touching every test, the new `eventType` field on `CalendarEvent` MUST have a default value of `nil` via an explicit memberwise init. This is the only "backwards compatibility" allowed in this plan, approved by Ben as the smallest reasonable change.
- **Two-place filter pattern.** Existing setting `hideDeclinedEvents` filters in both `CalendarManager.fetchEvents` (lines 227-231) and `CountdownModel.updateState` (lines 164-167). The new filter MUST mirror this exactly so that toggling the setting takes effect immediately AND so that `nextEvent` skips hidden entries on the next poll.
- **Line numbers in this plan are a snapshot of `main` at the time of writing.** If the executor lands on a file whose contents have shifted, trust the surrounding context (e.g. "after the `hideDeclinedEvents` didSet block", "immediately before `private var dismissedEventID`") rather than the absolute line number. Use Grep for structural anchors if in doubt.

---

## Task 1: Plumb `eventType` through CalendarClient

**Files:**
- Test: `CountdownTests/CalendarClientTests.swift` (insert new `@Test` immediately before `filtersAllDayEvents()`)
- Modify: `Countdown/CalendarEvent.swift` (`RawCalendarEvent` struct and `CalendarEvent` struct)
- Modify: `Countdown/CalendarClient.swift` (compactMap return inside `fetchEvents`)

**Step 1.1: Write the failing test**

Add this test to `CountdownTests/CalendarClientTests.swift`, immediately before `@Test func filtersAllDayEvents()`:

```swift
@Test func parsesEventType() async throws {
    let json = """
    {
        "items": [
            {
                "id": "taskevt",
                "summary": "Buy milk",
                "status": "confirmed",
                "eventType": "task",
                "start": { "dateTime": "2026-03-01T09:00:00Z" },
                "end": { "dateTime": "2026-03-01T09:15:00Z" }
            },
            {
                "id": "defaultevt",
                "summary": "Standup",
                "status": "confirmed",
                "eventType": "default",
                "start": { "dateTime": "2026-03-01T10:00:00Z" },
                "end": { "dateTime": "2026-03-01T10:30:00Z" }
            },
            {
                "id": "noeventtype",
                "summary": "Legacy event",
                "status": "confirmed",
                "start": { "dateTime": "2026-03-01T11:00:00Z" },
                "end": { "dateTime": "2026-03-01T11:30:00Z" }
            }
        ]
    }
    """
    await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        return (response, Data(json.utf8))
    }

    let client = CalendarClient(session: session)
    let events = try await client.fetchEvents(
        accessToken: "test-token",
        from: Date(),
        to: Date().addingTimeInterval(3600)
    )

    #expect(events.count == 3)
    #expect(events.first { $0.id == "taskevt" }?.eventType == "task")
    #expect(events.first { $0.id == "defaultevt" }?.eventType == "default")
    #expect(events.first { $0.id == "noeventtype" }?.eventType == nil)
}
```

**Step 1.2: Run the test to verify it fails**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test \
  -only-testing:CountdownTests/CalendarClientTests 2>&1 | tail -30
```

Expected: build failure with `error: value of type 'CalendarEvent' has no member 'eventType'` (3 occurrences). Note that `-only-testing` selectors target the file/suite, not individual `@Test` methods, so this command runs all CalendarClient tests.

**Step 1.3: Add `eventType` to `RawCalendarEvent`**

In `Countdown/CalendarEvent.swift`, modify the `RawCalendarEvent` struct:

```swift
struct RawCalendarEvent: Decodable {
    let id: String
    let summary: String?
    let status: String?
    let eventType: String?
    let start: EventDateTime?
    let end: EventDateTime?
    let attendees: [EventAttendee]?
}
```

**Step 1.4: Add `eventType` to `CalendarEvent` with a defaulted init**

In the same file, replace the `CalendarEvent` struct:

```swift
struct CalendarEvent {
    let id: String
    let summary: String
    let startTime: Date
    let endTime: Date
    let hasOtherAttendees: Bool
    let eventType: String?

    init(
        id: String,
        summary: String,
        startTime: Date,
        endTime: Date,
        hasOtherAttendees: Bool,
        eventType: String? = nil
    ) {
        self.id = id
        self.summary = summary
        self.startTime = startTime
        self.endTime = endTime
        self.hasOtherAttendees = hasOtherAttendees
        self.eventType = eventType
    }
}
```

The explicit init with a default lets every existing test/source caller continue passing 5 args without modification.

**Step 1.5: Pass `eventType` through in `CalendarClient.fetchEvents`**

In `Countdown/CalendarClient.swift`, modify the `compactMap` return inside `fetchEvents`:

```swift
return CalendarEvent(
    id: raw.id,
    summary: raw.summary ?? "(No title)",
    startTime: startTime,
    endTime: endTime,
    hasOtherAttendees: !otherAttendees.isEmpty,
    eventType: raw.eventType
)
```

**Step 1.6: Run the test to verify it passes**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test \
  -only-testing:CountdownTests/CalendarClientTests 2>&1 | tail -30
```

Expected: All 9 tests in `CalendarClient` suite pass (8 previous + the new `parsesEventType()`).

**Step 1.7: Commit**

```bash
git add Countdown/CalendarEvent.swift Countdown/CalendarClient.swift CountdownTests/CalendarClientTests.swift
git commit -m "$(cat <<'EOF'
Plumb Google Calendar eventType field into CalendarEvent

Captures the API's eventType ("task", "birthday", "default", etc.)
so downstream filters can decide whether to surface an event.
EOF
)"
```

---

## Task 2: Add `hideTasksAndBirthdays` filter to CountdownModel

**Files:**
- Test: `CountdownTests/CountdownModelTests.swift`
- Modify: `Countdown/CountdownModel.swift`

**Step 2.1: Update DefaultsSnapshot keys**

There are two `DefaultsSnapshot` sites that mirror the full set of model-backed UserDefaults keys. Both must be kept in sync so that a test which toggles `hideTasksAndBirthdays` in one suite doesn't leak into the other.

In `CountdownTests/CountdownModelTests.swift`, modify the snapshot (currently at lines 10-13). Add `"hideTasksAndBirthdays"` to the list:

```swift
private let _snapshot = DefaultsSnapshot(keys: [
    "meetingsOnly", "showingEventDetails", "compactMode",
    "hideDeclinedEvents", "sizeMode", "autoReposition", "repositionCorner",
    "hideTasksAndBirthdays",
])
```

In `CountdownTests/OverlayPositionTests.swift`, modify the `OverlayLayoutStateModelTests` snapshot (currently at lines 584-587) the same way:

```swift
private let _snapshot = DefaultsSnapshot(keys: [
    "meetingsOnly", "showingEventDetails", "compactMode",
    "hideDeclinedEvents", "sizeMode", "autoReposition", "repositionCorner",
    "hideTasksAndBirthdays",
])
```

**Step 2.2: Write the failing tests**

Insert these tests into `CountdownTests/CountdownModelTests.swift` immediately after the `hideDeclinedEventsPersists` test (which ends around line 650, just before `// MARK: - Size mode`):

```swift
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
```

**Step 2.3: Run the tests to verify they fail**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test \
  -only-testing:CountdownTests/CountdownModelTests 2>&1 | tail -30
```

Expected: build failure with multiple `error: value of type 'CountdownModel' has no member 'hideTasksAndBirthdays'` errors.

**Step 2.4: Add the property and persistence to `CountdownModel`**

In `Countdown/CountdownModel.swift`, immediately after the `hideDeclinedEvents` property (currently lines 30-32), add:

```swift
/// When true, filters out non-meeting Google Calendar event types
/// (tasks, birthdays, out-of-office, working location, Gmail-extracted
/// events). Keeps `default` and `focusTime` events.
var hideTasksAndBirthdays: Bool {
    didSet { defaults.set(hideTasksAndBirthdays, forKey: DefaultsKey.hideTasksAndBirthdays) }
}
```

**Step 2.5: Initialise the property**

In the same file, in the `init` (currently starting at line 72), immediately after the `hideDeclinedEvents` initialisation block (currently lines 75-79, ending with the closing `}` of the `if/else`), add:

```swift
self.hideTasksAndBirthdays = defaults.bool(forKey: DefaultsKey.hideTasksAndBirthdays)
```

(`defaults.bool(forKey:)` returns `false` for missing keys, which is the desired default.)

**Step 2.6: Add the static set of hidden eventTypes**

In the same file, immediately before `private var dismissedEventID: String?` (currently line 69), add:

```swift
static let nonMeetingEventTypes: Set<String> = [
    "task", "birthday", "fromGmail", "outOfOffice", "workingLocation",
]
```

**Step 2.7: Add the filter check in `updateState()`**

In `Countdown/CountdownModel.swift`, immediately after the `hideDeclinedEvents` block in `updateState()` (currently lines 164-167):

```swift
if hideDeclinedEvents && (event.summary.hasPrefix("Declined:") || event.summary.hasPrefix("Cancelled:")) {
    setIdleOrHidden()
    return
}
```

…insert this block right after:

```swift
if hideTasksAndBirthdays && CountdownModel.nonMeetingEventTypes.contains(event.eventType ?? "") {
    setIdleOrHidden()
    return
}
```

**Step 2.8: Add the DefaultsKey**

In the same file, modify the `DefaultsKey` enum (currently lines 218-226) to add the new key. The result should be:

```swift
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
```

**Step 2.9: Run the tests to verify they pass**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test \
  -only-testing:CountdownTests/CountdownModelTests 2>&1 | tail -30
```

Expected: All `CountdownModel` tests pass (existing + 9 new ones for `hideTasksAndBirthdays`).

**Step 2.10: Commit**

```bash
git add Countdown/CountdownModel.swift CountdownTests/CountdownModelTests.swift CountdownTests/OverlayPositionTests.swift
git commit -m "$(cat <<'EOF'
Add hideTasksAndBirthdays filter to CountdownModel

When enabled, suppresses tasks, birthdays, out-of-office,
working-location, and Gmail-extracted events. Default and
focusTime events are unaffected.
EOF
)"
```

---

## Task 3: Wire `setHideTasksAndBirthdays` in CalendarManager

**Files:**
- Test: `CountdownTests/CalendarManagerTests.swift` (snapshot at lines 40-43, new test after `setHideDeclinedEventsUpdatesOverlayImmediately` ending around line 198)
- Modify: `Countdown/CalendarManager.swift`

**Step 3.1: Update DefaultsSnapshot in CalendarManagerTests**

In `CountdownTests/CalendarManagerTests.swift`, modify the snapshot (currently at lines 40-43):

```swift
private let _snapshot = DefaultsSnapshot(keys: [
    "meetingsOnly", "enabledCalendarIDs",
    "hideDeclinedEvents", "hideTasksAndBirthdays",
])
```

**Step 3.2: Write the failing setter test**

In `CountdownTests/CalendarManagerTests.swift`, immediately after the closing `}` of the `setHideDeclinedEventsUpdatesOverlayImmediately` test (around line 198), add:

```swift
@Test @MainActor func setHideTasksAndBirthdaysUpdatesOverlayImmediately() {
    let manager = CalendarManager()
    manager.model.setEvents([])
    manager.model.hideTasksAndBirthdays = false
    manager.model.nextEvent = CalendarEvent(
        id: "1",
        summary: "Buy milk",
        startTime: Date().addingTimeInterval(30 * 60),
        endTime: Date().addingTimeInterval(60 * 60),
        hasOtherAttendees: false,
        eventType: "task"
    )
    manager.model.updateState()
    #expect(manager.model.isIdle == false)

    manager.setHideTasksAndBirthdays(true)

    #expect(manager.model.hideTasksAndBirthdays == true)
    #expect(manager.model.isIdle == true)
}
```

**Step 3.3: Run the test to verify it fails**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test \
  -only-testing:CountdownTests/CalendarManagerTests 2>&1 | tail -20
```

Expected: build failure with `error: value of type 'CalendarManager' has no member 'setHideTasksAndBirthdays'`.

**Step 3.4: Add the setter to CalendarManager**

In `Countdown/CalendarManager.swift`, immediately after the closing `}` of `setHideDeclinedEvents` (currently lines 157-161), add:

```swift
func setHideTasksAndBirthdays(_ value: Bool) {
    model.hideTasksAndBirthdays = value
    model.updateState()
    poll()
}
```

**Step 3.5: Run the setter test to verify it passes**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test \
  -only-testing:CountdownTests/CalendarManagerTests 2>&1 | tail -20
```

Expected: all manager tests (including the new setter test) pass. The pre-filter is not yet in place, but the setter test doesn't exercise it — it only checks that toggling the setter idles the current overlay via `updateState`.

**Step 3.6: Write the failing fetch-filter test**

This second test is the critical one: it specifically verifies that the `fetchEvents` pre-filter drops hidden events *before* they reach `model.setEvents`, so that `model.nextEvent` points at the first visible entry rather than the first chronological one. Without this test, the setter test alone would still pass even if `fetchEvents` never pre-filtered at all (because `updateState` would idle the task after the fact).

In `CountdownTests/CalendarManagerTests.swift`, immediately after the `setHideTasksAndBirthdaysUpdatesOverlayImmediately` test you just added, append:

```swift
@Test @MainActor func fetchEventsFiltersHiddenEventTypesBeforeSelectingNextEvent() async {
    let session = ManagerMockProtocol.makeSession()
    let manager = CalendarManager(session: session)
    manager.config = Config(clientID: "test-id", clientSecret: "test-secret")
    manager.isSignedIn = true
    manager.refreshToken = "valid-refresh"
    manager.accessToken = "valid-token"
    manager.tokenExpiry = Date().addingTimeInterval(3600)
    manager.model.hideTasksAndBirthdays = true

    // Task starts earlier than the meeting. Without the pre-filter,
    // CountdownModel.setEvents would pick the task as nextEvent. With
    // the pre-filter the task is dropped and the meeting wins.
    let now = Date()
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let taskStart = formatter.string(from: now.addingTimeInterval(10 * 60))
    let taskEnd = formatter.string(from: now.addingTimeInterval(15 * 60))
    let meetingStart = formatter.string(from: now.addingTimeInterval(20 * 60))
    let meetingEnd = formatter.string(from: now.addingTimeInterval(50 * 60))

    await ManagerMockProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
        let path = request.url!.path
        let json: String
        if path.contains("/calendarList") {
            json = #"{"items":[{"id":"primary","summary":"Work","backgroundColor":"#4285f4"}]}"#
        } else {
            json = """
            {
                "items": [
                    {
                        "id": "task1",
                        "summary": "Buy milk",
                        "status": "confirmed",
                        "eventType": "task",
                        "start": { "dateTime": "\(taskStart)" },
                        "end": { "dateTime": "\(taskEnd)" }
                    },
                    {
                        "id": "meeting1",
                        "summary": "Standup",
                        "status": "confirmed",
                        "eventType": "default",
                        "start": { "dateTime": "\(meetingStart)" },
                        "end": { "dateTime": "\(meetingEnd)" }
                    }
                ]
            }
            """
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        return (response, Data(json.utf8))
    }

    await manager.fetchEvents()

    #expect(manager.model.nextEvent?.id == "meeting1")
}
```

**Step 3.7: Run the fetch-filter test to verify it fails**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test \
  -only-testing:CountdownTests/CalendarManagerTests 2>&1 | tail -30
```

Expected: the new `fetchEventsFiltersHiddenEventTypesBeforeSelectingNextEvent` test fails because `nextEvent?.id` is `"task1"` (the earlier event) — the pre-filter isn't in place yet, so `model.setEvents` picks the task. All other tests still pass.

**Step 3.8: Add the pre-filter in `fetchEvents`**

In `Countdown/CalendarManager.swift`, in `fetchEvents`, immediately after the `hideDeclinedEvents` filter block (currently lines 227-231):

```swift
if model.hideDeclinedEvents {
    filtered = filtered.filter {
        !$0.summary.hasPrefix("Declined:") && !$0.summary.hasPrefix("Cancelled:")
    }
}
```

…insert this block right after:

```swift
if model.hideTasksAndBirthdays {
    filtered = filtered.filter {
        !CountdownModel.nonMeetingEventTypes.contains($0.eventType ?? "")
    }
}
```

**Step 3.9: Run the tests to verify they pass**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test \
  -only-testing:CountdownTests/CalendarManagerTests 2>&1 | tail -30
```

Expected: all `CalendarManager` tests pass, including both new tests.

**Step 3.10: Commit**

```bash
git add Countdown/CalendarManager.swift CountdownTests/CalendarManagerTests.swift
git commit -m "$(cat <<'EOF'
Wire hideTasksAndBirthdays filter through CalendarManager

Pre-filters events at fetch time so nextEvent skips hidden
entries, and exposes a setter that re-renders the overlay
immediately on toggle.
EOF
)"
```

---

## Task 4: Add the SettingsView toggle

**Files:**
- Modify: `Countdown/SettingsView.swift` (add toggle in `eventsSection` around line 146, add binding after `hideDeclinedBinding` around lines 386-391)

No unit test — SwiftUI views aren't unit-tested in this project; verification is visual via the `--preview-settings` harness (see CLAUDE.md § "Settings UI Preview Harness").

**Step 4.1: Add the binding**

In `Countdown/SettingsView.swift`, immediately after the closing `}` of `hideDeclinedBinding` (currently lines 386-391), add:

```swift
private var hideTasksAndBirthdaysBinding: Binding<Bool> {
    Binding(
        get: { manager.model.hideTasksAndBirthdays },
        set: { manager.setHideTasksAndBirthdays($0) }
    )
}
```

**Step 4.2: Add the toggle inside `eventsSection`**

In `Countdown/SettingsView.swift`, the current `eventsSection` (around lines 134-148) looks like:

```swift
@ViewBuilder
private var eventsSection: some View {
    section("Events") {
        labeledControl("Show countdown for") {
            Picker("", selection: meetingsOnlyBinding) {
                Text("All events").tag(false)
                Text("Meetings only").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }

        inlineToggle("Hide declined & cancelled", isOn: hideDeclinedBinding)
    }
}
```

Add a new `inlineToggle` immediately after the `hideDeclinedBinding` one:

```swift
@ViewBuilder
private var eventsSection: some View {
    section("Events") {
        labeledControl("Show countdown for") {
            Picker("", selection: meetingsOnlyBinding) {
                Text("All events").tag(false)
                Text("Meetings only").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }

        inlineToggle("Hide declined & cancelled", isOn: hideDeclinedBinding)
        inlineToggle("Hide tasks & birthdays", isOn: hideTasksAndBirthdaysBinding)
    }
}
```

**Step 4.3: Build to confirm it compiles**

```bash
xcodebuild -project Countdown.xcodeproj -scheme Countdown build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

**Step 4.4 (optional): Visual verification via preview harness**

Per CLAUDE.md, the debug build supports a `--preview-settings` launch arg that renders `SettingsView` in a standalone window without going through the menu bar or Keychain flow. Use it to eyeball the new toggle:

```bash
xcodebuild -project Countdown.xcodeproj -scheme Countdown -configuration Debug build
pkill -x Countdown
"$(xcodebuild -project Countdown.xcodeproj -scheme Countdown -configuration Debug -showBuildSettings 2>/dev/null | awk '/CONFIGURATION_BUILD_DIR/ {print $3}')/Countdown.app/Contents/MacOS/Countdown" --preview-settings &
```

The new "Hide tasks & birthdays" toggle should appear in the Events section below "Hide declined & cancelled". Close the window when done.

**Step 4.5: Commit**

```bash
git add Countdown/SettingsView.swift
git commit -m "$(cat <<'EOF'
Add 'Hide tasks & birthdays' toggle to settings

Exposes the new filter alongside the existing meeting and
declined-event toggles in the Events section of the settings popover.
EOF
)"
```

---

## Task 5: Run the full test suite

**Step 5.1: Run all tests**

```bash
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test 2>&1 | tail -40
```

Expected: `** TEST SUCCEEDED **` with all suites passing. No new warnings.

**Step 5.2: Build the app target**

```bash
xcodebuild -project Countdown.xcodeproj -scheme Countdown build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

If both pass, the feature is complete. No further commit — Task 4 already covered the UI commit.

---

## Verification checklist

Before declaring done:

- [ ] Task 1 commit: `eventType` plumbed through CalendarClient + parsesEventType test passing
- [ ] Task 2 commit: `hideTasksAndBirthdays` property + 9 model tests passing
- [ ] Task 3 commit: `setHideTasksAndBirthdays` setter + two manager tests passing (setter immediacy + fetchEvents pre-filter) + pre-filter in fetchEvents
- [ ] Task 4 commit: SettingsView toggle wired up
- [ ] Task 5: full `xcodebuild test` clean, full `xcodebuild build` clean
- [ ] No new compiler warnings introduced
- [ ] No existing tests modified (only new ones added; the snapshot lists are the only edits to existing test code)
