# Calendar Selector Design

## Overview

Add a calendar selector to the settings panel, showing all the user's available
Google Calendars with toggles to enable/disable each one. The countdown considers
events from all enabled calendars when determining the next event.

## Data Model

New `CalendarInfo` struct representing a calendar from the Google API:

```swift
struct CalendarInfo: Identifiable {
    let id: String              // Google's calendar ID
    let summary: String         // Display name (e.g. "Work", "Personal")
    let backgroundColor: String // Hex colour from Google
}
```

Decodable counterparts added to `CalendarEvent.swift` for the `calendarList`
API response.

**Storage:** Enabled calendar IDs persisted in `UserDefaults` under key
`"enabledCalendarIDs"`. Empty/missing set means "all enabled" (default
behaviour when first connecting).

## CalendarClient Changes

1. **New `fetchCalendars` method** — `GET /calendar/v3/users/me/calendarList`,
   returns `[CalendarInfo]`. Same auth pattern as `fetchEvents`.

2. **Parameterise `fetchEvents`** — add `calendarID: String` parameter instead
   of hardcoding `"primary"`. URL becomes `.../calendars/{calendarID}/events`.

## CalendarManager Changes

- Stores `[CalendarInfo]` as observable property for the UI.
- On poll: fetches calendar list, then fetches events from each enabled
  calendar, merges results sorted by start time, picks earliest.
- Calendar list refreshed on sign-in and each poll cycle.
- Tracks enabled calendar IDs; defaults to all when set is empty.

## SettingsView Changes

New "Calendars" section between the filter and quit button. Only shown when
signed in and calendars have been fetched.

```
Calendars
  [colour dot] Work          [toggle on]
  [colour dot] Personal      [toggle on]
  [colour dot] Holidays      [toggle off]
```

Each row: colour dot (from Google's `backgroundColor`), calendar name, Toggle.

Calendar list wrapped in `ScrollView` with ~120pt max height to handle users
with many calendars. Panel height increases from fixed 260 to accommodate the
new section.

## Defaults

All calendars enabled by default (empty set in UserDefaults = all enabled).
Users opt out of calendars they don't want.
