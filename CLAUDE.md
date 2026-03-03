# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A macOS menu bar app (Swift 6, SwiftUI) that shows a floating countdown circle for upcoming Google Calendar events. The circle changes colour from green (60 min away) to red (imminent) and flashes when <1 min to start. No Dock icon — menu bar only (`LSUIElement=true`).

## Build & Test Commands

```bash
# Build
xcodebuild -project Countdown.xcodeproj -scheme Countdown build

# Run all tests
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test

# Run a single test class
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test -only-testing:CountdownTests/CountdownModelTests

# Run a single test method
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test -only-testing:CountdownTests/CountdownModelTests/testMethodName

# Regenerate Xcode project after changing project.yml
xcodegen generate
```

No external dependencies — everything uses native frameworks (SwiftUI, AppKit, Foundation, Security, CryptoKit, Network).

## Architecture

### Data Flow

```
GoogleAuth (browser OAuth + PKCE) → token stored in Keychain
    ↓
CalendarManager polls Google Calendar API every 60s
    ↓
Events filtered by enabled calendars + "meetings only" preference
    ↓
CountdownModel.setEvents() → updateState() computes:
  shouldShowOverlay, minutesRemaining, colourProgress, isFlashing
    ↓
AppDelegate observes model via withObservationTracking → updates OverlayPanel
    ↓
CircleView renders animated countdown circle
```

### Key Classes

- **CountdownApp** — SwiftUI `@main` entry point, creates `MenuBarExtra` with `.window` style
- **AppDelegate** — Owns `CalendarManager`, manages `OverlayPanel` visibility/sizing, uses `withObservationTracking` to react to model changes
- **CalendarManager** (`@Observable`, `@MainActor`) — Coordinates polling (60s API + 1s state update), token refresh, calendar filtering. Central orchestrator
- **CountdownModel** (`@Observable`) — Pure state: next event, time remaining, colour progress (0=green → 1=red), flash state, overlay visibility. 60-min lookahead window, 5-min post-start grace period
- **GoogleAuth** — Static OAuth 2.0 with PKCE, browser-based sign-in, token refresh/revocation
- **CalendarClient** — Google Calendar API wrapper using URLSession. Fetches calendar lists and events
- **OverlayPanel** (`NSPanel`) — Floating, always-on-top, draggable window. Position persisted to UserDefaults
- **RedirectListener** — Local HTTP server on random port for OAuth redirect callback

### State Persistence

- **Keychain**: OAuth refresh + access tokens (via `Keychain.swift` wrapper around Security framework)
- **UserDefaults**: `enabledCalendarIDs`, `meetingsOnly`, overlay position (`overlayX`/`overlayY`)

### Configuration

Users must provide Google OAuth credentials in `Countdown/Config.plist` (see `Config.plist.template`). `Config.load()` reads this at startup.

## Testing

Tests use Swift Testing framework (`@Suite`, `@Test`, `#expect`) — not XCTest. HTTP calls are mocked via `MockURLProtocol` which intercepts `URLSession` requests. Model test suites use `.serialized` to prevent concurrency issues.

## Project Generation

The Xcode project is generated from `project.yml` using XcodeGen. Edit `project.yml` for target/dependency changes, then run `xcodegen generate`.

## Documentation

When updating README.md or CONTRIBUTING.md, check the other file to ensure they stay in sync and don't contain duplicate or contradictory information.
