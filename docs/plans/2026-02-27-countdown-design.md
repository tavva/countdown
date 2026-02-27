# Countdown: Meeting Countdown Overlay for macOS

## Overview

A macOS menu bar app that shows a floating circle on the desktop counting down
minutes until the next calendar event. The circle changes colour from green to
red as the meeting approaches, flashes when imminent, and hides when not
needed.

## Architecture

SwiftUI menu bar app with no Dock icon (`LSUIElement = true`). Two UI surfaces:

- **Floating overlay** — Borderless, always-on-top `NSPanel` showing the
  countdown circle. Positioned bottom-right of the main screen.
- **Menu bar popover** — Settings and status, opened by clicking the menu bar
  icon.

Key components:

- `CountdownApp` — App entry point, sets up menu bar and overlay window.
- `CalendarManager` — Polls Google Calendar API every 60 seconds. Publishes
  the next relevant event.
- `GoogleAuth` — Handles OAuth 2.0 flow: sign-in via browser, token storage in
  Keychain, silent refresh, revocation on disconnect.
- `OverlayWindow` — `NSPanel` subclass for the floating circle.
- `CountdownModel` — `@Observable` model holding next event, time remaining,
  and flash state.
- `SettingsView` — SwiftUI view for the menu bar popover.
- `CircleView` — SwiftUI view for the countdown circle.

No third-party dependencies. Uses `URLSession` for API calls, `Security`
framework for Keychain, native SwiftUI/AppKit for UI.

## Google OAuth Flow

1. **Sign in** — User clicks "Connect Google Account". App opens system browser
   to Google OAuth consent screen requesting `calendar.readonly` scope. A local
   HTTP server on a random port listens for the redirect callback.
2. **Token exchange** — On callback, exchanges auth code for access + refresh
   tokens. Refresh token stored in Keychain. Access token held in memory with
   expiry.
3. **Token refresh** — Before each API call, silently refreshes expired access
   tokens using the stored refresh token.
4. **Sign out** — Revokes token via Google's revocation endpoint, deletes
   Keychain entry.

OAuth client ID and secret are stored in a `Config.plist` that the user
populates from their Google Cloud Console. The app shows a setup message if
credentials are missing.

**Calendar API:** Single endpoint —
`GET /calendars/primary/events` with `timeMin=now`, `timeMax=now+60m`,
`singleEvents=true`, `orderBy=startTime`. Response parsed for event start
times and attendee lists.

## Overlay Circle UI & Behaviour

~80pt diameter circle with minutes remaining centred inside.

### Colour states

| State                        | Appearance                                      |
|------------------------------|-------------------------------------------------|
| Normal (>5 min)              | Green (60 min) → orange (5 min), linear interpolation |
| Urgent (1–5 min)             | Solid red                                       |
| Flashing (<1 min before to 5 min after start) | Pulses red ↔ bright red, ~1s cycle |

### Flash termination

Flashing stops when either:
- 5 minutes have elapsed since the meeting started, OR
- The user clicks the circle.

In both cases the circle hides for that event, then checks for the next event
within the 60-minute window.

### Window properties

- `NSPanel` with `level = .floating`, non-activating
- No title bar, no shadow, transparent background
- Bottom-right of main screen, 20pt padding from edges
- Responds to mouse clicks (not click-through)

### Display

- Shows whole minutes remaining (e.g. "23")
- Shows "0" during the final minute and post-start flash period
- Hidden when no events within 60 minutes

## Settings Panel (Menu Bar Popover)

- **Status line** — "Next: [Event Name] in [N] min" or "No upcoming events"
- **Google Account** — Connected email + "Disconnect" button, or "Connect
  Google Account" button. Setup instructions shown if `Config.plist` is missing.
- **Events toggle** — "Show countdown for:" with options "All events" /
  "Meetings only (with other attendees)". Default: All events. Stored in
  `UserDefaults`.

## Menu Bar Icon

Small circle icon reflecting current state: coloured when counting down, grey
when idle.
