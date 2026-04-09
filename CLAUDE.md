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

## Settings UI Preview Harness

For iterating on `SettingsView` visually without going through the full menu-bar flow (which requires a code-signing identity that matches the Keychain entries), the debug build accepts a `--preview-settings` launch argument. When present, `AppDelegate` skips the overlay/polling/keychain path and instead opens `SettingsView` in a standalone resizable `NSWindow` populated with mock state.

```bash
# Build debug
xcodebuild -project Countdown.xcodeproj -scheme Countdown -configuration Debug build

# Launch with preview arg (kill any running instance first)
pkill -x Countdown
"$(xcodebuild -project Countdown.xcodeproj -scheme Countdown -configuration Debug -showBuildSettings 2>/dev/null | awk '/CONFIGURATION_BUILD_DIR/ {print $3}')/Countdown.app/Contents/MacOS/Countdown" --preview-settings &
```

The preview path:
- Skips `loadStoredTokens()` so there's no Keychain prompt for the unsigned debug build
- Sets fake `CalendarManager` state via the `#if DEBUG` `setPreviewCalendars(_:)` helper
- Reads a `PREVIEW_STATE` env var to switch between `empty` (default), `with-event`, `signed-out`, `no-config`
- Logs a `PREVIEW_RECT <x> <y> <w> <h>` line to stderr in the screencapture coordinate system, ready to feed into `screencapture -R`
- Lives entirely behind `#if DEBUG`, so it's compiled out of release builds

To capture the window, read the rect from stderr then:

```bash
screencapture -x -R<x>,<y>,<w>,<h> /tmp/settings.png
```

Set `PREVIEW_STATE=with-event` (etc.) before launching to exercise other states. Mock calendars and the in-DEBUG helper live in `AppDelegate.swift` (`setupSettingsPreview` + `previewCalendars`).

## Project Generation

The Xcode project is generated from `project.yml` using XcodeGen. Edit `project.yml` for target/dependency changes, then run `xcodegen generate`.

## Releasing

Releases are handled by `scripts/build-release.sh <version>`. Do NOT manually create GitHub releases, tags, or version bumps — the script does all of this:

1. Bumps the version in `Info.plist` and commits
2. Archives, code-signs, and notarises the app
3. Creates a signed DMG
4. Signs the DMG with EdDSA for Sparkle auto-update
5. Updates `appcast.xml` on the `gh-pages` branch
6. Tags and pushes
7. Creates the GitHub release with the DMG attached

```bash
# Prerequisite (one-time): download Sparkle signing tools
scripts/download-sparkle-tools.sh

# Release (e.g. version 1.5.6)
scripts/build-release.sh 1.5.6
```

The script requires a Developer ID Application certificate and stored notarisation credentials (`NOTARIZE_PROFILE`, defaults to `countdown-notarize`). The working tree must be clean before running.

## Documentation

When updating README.md or CONTRIBUTING.md, check the other file to ensure they stay in sync and don't contain duplicate or contradictory information.
