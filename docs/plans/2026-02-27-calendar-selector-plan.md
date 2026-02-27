# Calendar Selector Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add per-calendar toggles to the settings panel so users can choose which Google Calendars contribute to the countdown.

**Architecture:** Add a `fetchCalendars` method to `CalendarClient`, parameterise `fetchEvents` by calendar ID, store enabled calendar IDs in `UserDefaults`, and add a toggle list to `SettingsView`. `CalendarManager` orchestrates fetching from multiple calendars and merging results.

**Tech Stack:** Swift 6.0, SwiftUI, macOS 14+, Google Calendar API, Swift Testing

---

### Task 1: Add CalendarInfo model and decodable types

**Files:**
- Modify: `Countdown/CalendarEvent.swift`

**Step 1: Add decodable types for the calendarList API response**

Add these types at the end of `CalendarEvent.swift`:

```swift
struct CalendarListResponse: Decodable {
    let items: [RawCalendarInfo]?
}

struct RawCalendarInfo: Decodable {
    let id: String
    let summary: String?
    let backgroundColor: String?
}

struct CalendarInfo: Identifiable, Equatable {
    let id: String
    let summary: String
    let backgroundColor: String
}
```

**Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Countdown -destination 'platform=macOS' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
git add Countdown/CalendarEvent.swift
git commit -m "Add CalendarInfo model for calendar list API"
```

---

### Task 2: Add fetchCalendars to CalendarClient

**Files:**
- Modify: `Countdown/CalendarClient.swift`
- Test: `CountdownTests/CalendarClientTests.swift`

**Step 1: Write failing test for fetchCalendars**

Add to `CalendarClientTests`:

```swift
@Test func fetchCalendarsParsesResponse() async throws {
    let json = """
    {
        "items": [
            {
                "id": "primary",
                "summary": "Work",
                "backgroundColor": "#4285f4"
            },
            {
                "id": "personal@gmail.com",
                "summary": "Personal",
                "backgroundColor": "#0b8043"
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
    let calendars = try await client.fetchCalendars(accessToken: "test-token")

    #expect(calendars.count == 2)
    #expect(calendars[0].id == "primary")
    #expect(calendars[0].summary == "Work")
    #expect(calendars[0].backgroundColor == "#4285f4")
    #expect(calendars[1].id == "personal@gmail.com")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Countdown -destination 'platform=macOS' 2>&1 | grep -E "(fetchCalendars|error:|BUILD)"`
Expected: Build error — `fetchCalendars` does not exist

**Step 3: Implement fetchCalendars**

Add to `CalendarClient`:

```swift
func fetchCalendars(accessToken: String) async throws -> [CalendarInfo] {
    let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!

    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await session.data(for: request)
    let http = response as! HTTPURLResponse

    guard http.statusCode != 401 else {
        throw CalendarClientError.unauthorised
    }
    guard http.statusCode == 200 else {
        throw CalendarClientError.httpError(http.statusCode)
    }

    let decoded = try JSONDecoder().decode(CalendarListResponse.self, from: data)
    let items = decoded.items ?? []

    return items.map { raw in
        CalendarInfo(
            id: raw.id,
            summary: raw.summary ?? "(No name)",
            backgroundColor: raw.backgroundColor ?? "#888888"
        )
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Countdown -destination 'platform=macOS' 2>&1 | grep -E "(fetchCalendars|passed|failed|Test run)"`
Expected: `fetchCalendarsParsesResponse` passes

**Step 5: Commit**

```
git add Countdown/CalendarClient.swift CountdownTests/CalendarClientTests.swift
git commit -m "Add fetchCalendars method to CalendarClient"
```

---

### Task 3: Parameterise fetchEvents by calendar ID

**Files:**
- Modify: `Countdown/CalendarClient.swift`
- Modify: `CountdownTests/CalendarClientTests.swift`
- Modify: `Countdown/CalendarManager.swift`

**Step 1: Write failing test that fetchEvents uses the provided calendar ID**

Add to `CalendarClientTests`:

```swift
@Test func fetchEventsUsesProvidedCalendarID() async throws {
    nonisolated(unsafe) var capturedURL: URL?
    await MockURLProtocol.requestHandler.set(forHost: "www.googleapis.com") { request in
        capturedURL = request.url
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
        )!
        return (response, Data(#"{"items":[]}"#.utf8))
    }

    let client = CalendarClient(session: session)
    _ = try await client.fetchEvents(
        accessToken: "test",
        calendarID: "work@example.com",
        from: Date(),
        to: Date().addingTimeInterval(3600)
    )

    #expect(capturedURL!.path.contains("/calendars/work@example.com/events"))
}
```

**Step 2: Run test to verify it fails**

Expected: Build error — extra argument `calendarID`

**Step 3: Add calendarID parameter to fetchEvents**

Change the `fetchEvents` signature to:

```swift
func fetchEvents(
    accessToken: String,
    calendarID: String = "primary",
    from start: Date,
    to end: Date
) async throws -> [CalendarEvent] {
```

And change the URL construction from hardcoded `"primary"` to:

```swift
var components = URLComponents(
    string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID)/events"
)!
```

The default value `"primary"` means all existing call sites (CalendarManager, existing tests) continue to work without changes.

**Step 4: Run all tests to verify they pass**

Run: `xcodebuild test -scheme Countdown -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|Test run)"`
Expected: All tests pass including the new one

**Step 5: Commit**

```
git add Countdown/CalendarClient.swift CountdownTests/CalendarClientTests.swift
git commit -m "Parameterise fetchEvents with calendarID"
```

---

### Task 4: Add calendar state tracking to CalendarManager

**Files:**
- Modify: `Countdown/CalendarManager.swift`

**Step 1: Add calendar list and enabled set properties**

Add to `CalendarManager`:

```swift
private(set) var calendars: [CalendarInfo] = []

var enabledCalendarIDs: Set<String> {
    get {
        let stored = UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs")
        guard let stored else { return [] }
        return Set(stored)
    }
    set {
        UserDefaults.standard.set(Array(newValue), forKey: "enabledCalendarIDs")
    }
}
```

An empty set means "all enabled" (the default).

**Step 2: Add a helper to check if a calendar is enabled**

```swift
func isCalendarEnabled(_ id: String) -> Bool {
    let enabled = enabledCalendarIDs
    return enabled.isEmpty || enabled.contains(id)
}

func toggleCalendar(_ id: String) {
    var enabled = enabledCalendarIDs
    if enabled.isEmpty {
        // Switching from "all enabled" to explicit set: add all except the toggled one
        enabled = Set(calendars.map(\.id))
        enabled.remove(id)
    } else if enabled.contains(id) {
        enabled.remove(id)
    } else {
        enabled.insert(id)
        // If all calendars are now enabled, reset to empty (= all)
        if enabled == Set(calendars.map(\.id)) {
            enabled = []
        }
    }
    enabledCalendarIDs = enabled
}
```

**Step 3: Update fetchEvents to fetch from multiple calendars**

Replace the current `fetchEvents()` private method:

```swift
private func fetchEvents() async {
    guard let config else { return }

    do {
        let token = try await validAccessToken(config: config)

        let fetchedCalendars = try await calendarClient.fetchCalendars(accessToken: token)
        calendars = fetchedCalendars

        let now = Date()
        let end = now.addingTimeInterval(60 * 60)

        let enabledIDs = enabledCalendarIDs
        let calendarsToFetch = fetchedCalendars.filter { cal in
            enabledIDs.isEmpty || enabledIDs.contains(cal.id)
        }

        var allEvents: [CalendarEvent] = []
        for cal in calendarsToFetch {
            let events = try await calendarClient.fetchEvents(
                accessToken: token,
                calendarID: cal.id,
                from: now,
                to: end
            )
            allEvents.append(contentsOf: events)
        }

        allEvents.sort { $0.startTime < $1.startTime }

        let filtered: [CalendarEvent]
        if model.meetingsOnly {
            filtered = allEvents.filter { $0.hasOtherAttendees }
        } else {
            filtered = allEvents
        }

        model.nextEvent = filtered.first
        model.updateState()
        errorMessage = nil
    } catch CalendarClientError.unauthorised {
        isSignedIn = false
        errorMessage = "Session expired. Please sign in again."
        stopPolling()
    } catch {
        errorMessage = "Failed to fetch events: \(error.localizedDescription)"
    }
}
```

**Step 4: Build and run all tests**

Run: `xcodebuild test -scheme Countdown -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|Test run)"`
Expected: All existing tests still pass

**Step 5: Commit**

```
git add Countdown/CalendarManager.swift
git commit -m "Add multi-calendar support to CalendarManager"
```

---

### Task 5: Add calendar selector to SettingsView

**Files:**
- Modify: `Countdown/SettingsView.swift`

**Step 1: Add the calendar section**

Add a new `calendarsSection` computed property:

```swift
@ViewBuilder
private var calendarsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Calendars")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        ScrollView {
            VStack(spacing: 4) {
                ForEach(manager.calendars) { calendar in
                    HStack {
                        Circle()
                            .fill(Color(hex: calendar.backgroundColor))
                            .frame(width: 10, height: 10)
                        Text(calendar.summary)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { manager.isCalendarEnabled(calendar.id) },
                            set: { _ in manager.toggleCalendar(calendar.id) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                }
            }
        }
        .frame(maxHeight: 120)
    }
}
```

**Step 2: Add Color(hex:) initialiser**

Add a small extension (can be at the bottom of `SettingsView.swift`):

```swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
```

**Step 3: Wire the section into the body**

Update the `body` to insert `calendarsSection` between `filterSection` and `Spacer`, with a `Divider`. Only show when signed in and calendars are non-empty:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 16) {
        statusSection
        Divider()
        accountSection
        Divider()
        filterSection

        if manager.isSignedIn && !manager.calendars.isEmpty {
            Divider()
            calendarsSection
        }

        Spacer()

        HStack {
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
    .padding()
    .frame(width: 280, minHeight: 260)
}
```

Note: changed `height: 260` to `minHeight: 260` so the panel grows when calendars are shown.

**Step 4: Build to verify it compiles**

Run: `xcodebuild build -scheme Countdown -destination 'platform=macOS' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Run all tests to verify nothing is broken**

Run: `xcodebuild test -scheme Countdown -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|Test run)"`
Expected: All tests pass

**Step 6: Commit**

```
git add Countdown/SettingsView.swift
git commit -m "Add calendar selector with toggles to settings panel"
```

---

### Task 6: Clear calendar preferences on sign-out

**Files:**
- Modify: `Countdown/CalendarManager.swift`

**Step 1: Update signOut to clear calendar state**

In `CalendarManager.signOut()`, add after existing cleanup:

```swift
calendars = []
UserDefaults.standard.removeObject(forKey: "enabledCalendarIDs")
```

**Step 2: Build and run all tests**

Run: `xcodebuild test -scheme Countdown -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|Test run)"`
Expected: All tests pass

**Step 3: Commit**

```
git add Countdown/CalendarManager.swift
git commit -m "Clear calendar preferences on sign-out"
```

---

### Task 7: Manual verification

**Step 1: Build and launch the app**

Run: `xcodebuild build -scheme Countdown -destination 'platform=macOS' -quiet 2>&1 | tail -5`

**Step 2: Verify visually**

- Click menu bar icon → settings panel opens
- When signed in, "Calendars" section appears below "Show countdown for"
- Each calendar shows a colour dot, name, and toggle
- Toggling a calendar off/on works
- If all calendars are toggled on, the stored set resets to empty (all enabled)
- Sign out → calendar section disappears, preferences cleared
- Sign back in → all calendars show as enabled (default)

**Step 3: Run full test suite one final time**

Run: `xcodebuild test -scheme Countdown -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|Test run)"`
Expected: All tests pass
