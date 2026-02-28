# Countdown

A macOS menu bar app that floats a countdown circle on your screen showing minutes until your next Google Calendar event. The circle shifts from green to orange to red as the event approaches, and pulses when it's about to start — so you never lose track of time.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![Licence](https://img.shields.io/badge/licence-MIT-green)

## Features

- **Floating countdown circle** — always-on-top overlay, draggable to any position
- **Colour transitions** — green (60 min) → orange → red (imminent) → pulsing flash at <1 min
- **Multi-calendar support** — select which Google Calendars to watch
- **Meetings filter** — optionally show only events with other attendees
- **Tap for details** — tap the circle to see event name and time range
- **Zero dependencies** — built entirely with native Swift, SwiftUI, and AppKit

## Setup

### Prerequisites

- macOS 14.0 or later
- [Xcode](https://developer.apple.com/xcode/) (with command-line tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Google OAuth credentials (see below)

### Google OAuth Credentials

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project (or select an existing one)
3. Enable the **Google Calendar API**
4. Go to **Credentials** → **Create Credentials** → **OAuth client ID**
5. Choose **Desktop app** as the application type
6. Copy the **Client ID** and **Client Secret**

### Build & Run

```bash
# Clone the repo
git clone https://github.com/tavva/countdown.git
cd countdown

# Add your OAuth credentials
cp Countdown/Config.plist.template Countdown/Config.plist
# Edit Config.plist — fill in GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET

# Generate the Xcode project
xcodegen generate

# Build and run
xcodebuild -project Countdown.xcodeproj -scheme Countdown build
open DerivedData/Build/Products/Debug/Countdown.app
```

Or open `Countdown.xcodeproj` in Xcode and hit Run.

### First Launch

1. Click the circle icon in your menu bar
2. Click **Connect Google Account**
3. Authorise in your browser
4. The countdown circle appears when an event is within 60 minutes

## Usage

The app lives entirely in your menu bar. Click the menu bar icon to:

- See your next upcoming event
- Connect or disconnect your Google account
- Toggle between **All events** and **Meetings only**
- Enable/disable individual calendars

The floating countdown circle appears automatically when an event is within 60 minutes and disappears 5 minutes after it starts. Drag it anywhere on screen — the position is remembered between launches.

## Development

```bash
# Run all tests
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests test

# Run a single test class
xcodebuild -project Countdown.xcodeproj -scheme CountdownTests \
  test -only-testing:CountdownTests/CountdownModelTests
```

The project is generated from `project.yml` using XcodeGen. Edit `project.yml` for target or dependency changes, then run `xcodegen generate`.

Tests use the Swift Testing framework (`@Test`, `#expect`), not XCTest.

## Licence

MIT — see [LICENCE](LICENCE) for details.
