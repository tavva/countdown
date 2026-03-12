# Compact Mode Design

## Goal

Add a smaller overlay option: a coloured dot with the minutes number beside it,
and optional event details to the right. Reduces the overlay footprint from
~200x120 to ~36px tall.

## Layout

**Standard mode (current):** Vertical stack — 80pt circle with number inside,
optional event details below. Panel ~200x120.

**Compact mode:** Horizontal row — ~20pt coloured dot (ring/flash preserved),
minutes label (~14pt) beside it, optional event details text to the right.
Panel ~36pt tall, width adapts to content.

## Changes

### CountdownModel
- Add `compactMode: Bool` backed by UserDefaults key `"compactMode"`, defaults
  to `false`.

### CircleView
- Add `compact: Bool` parameter.
- Compact: 20pt dot, 24pt ring with 2pt stroke, 28pt frame. No text/icon
  inside (too small). Loading spinner scaled to ~12pt.
- Standard: unchanged.

### OverlayContent (in AppDelegate)
- Compact: HStack with dot, minutes text (~14pt bold), optional event details.
- Standard: VStack as today.

### OverlayPanel
- Pass compact mode to CircleHitTestView so it can let all clicks through in
  compact mode (strip is already small).

### AppDelegate
- Observe `compactMode` changes to trigger panel resize.
- Adjust default width/height for compact mode.

### SettingsView
- Add "Circle size" picker (Standard / Compact) in filter section.

### Right-click menu
- Add "Compact mode" toggle item above "Settings…".

## Testing
- Model: `compactMode` default, persistence, toggle.
- Hit test: compact mode allows all clicks.
