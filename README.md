<p align="center">
  <img src="Countdown/Assets.xcassets/AppIcon.appiconset/icon_128@2x.png" width="128" height="128" alt="Countdown app icon">
</p>

<h1 align="center">Countdown</h1>

<p align="center">
  Never lose track of time.
</p>
<p align="center">
  A macOS menu bar app that floats a countdown circle on your screen showing minutes until your next Google Calendar event. The circle shifts from green to orange to red as the event approaches, and pulses when it's about to start.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/licence-GPL--3.0-blue" alt="Licence">
</p>

<p align="center">
  <img src="docs/meeting_1.png" width="220" alt="Green countdown circle showing 38 minutes until meeting">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/meeting_2.png" width="220" alt="Red countdown circle showing 6 minutes until meeting">
</p>

## Features

- **Floating countdown circle** — always-on-top overlay you can drag anywhere on screen
- **Colour transitions** — green (60 min) → orange → red (imminent) → pulsing flash at <1 min
- **Multi-calendar support** — choose which Google Calendars to watch, with colour-coded indicators
- **Meetings filter** — optionally show only events with other attendees
- **Tap for details** — tap the circle to see event name and time range
- **Launch at login** — start automatically when you log in
- **Zero dependencies** — built entirely with native Swift, SwiftUI, and AppKit

## How It Works

The countdown circle appears automatically when a Google Calendar event is within 60 minutes. It fills up as the event approaches, changing colour to convey urgency at a glance. When the event is less than a minute away, the circle pulses to get your attention — tap it to acknowledge. The circle disappears 5 minutes after the event starts.

All controls live in the menu bar popover: connect your Google account, pick which calendars to track, toggle the meetings-only filter, and choose whether the circle is always visible or only before events.

## Installation

### Requirements

- macOS 14.0 (Sonoma) or later

### Download

Download the latest `.dmg` from [GitHub Releases](https://github.com/tavva/countdown/releases), open it, and drag Countdown to your Applications folder.

### Getting Started

1. Click the circle icon in your menu bar
2. Click **Connect Google Account**
3. Authorise in your browser
4. The countdown circle appears when an event is within 60 minutes

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

[GPL v3](LICENCE)
