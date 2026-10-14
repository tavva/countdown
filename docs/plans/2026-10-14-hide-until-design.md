# Hide Until — Design

## Purpose

During a workshop or a day with other people, the countdown overlay is a
distraction. Ben wants to hide it for a while, usually until the next morning,
and have it come back on its own.

## Behaviour

### Hiding

The overlay's right-click menu gains two items:

- **Hide until tomorrow, 4am** — hides until the next 4am. If it is already
  past midnight but before 4am, that is 4am today, and the label reads
  "Hide until 4am" instead.
- **Hide until…** — opens a small window with a date-and-time picker, defaulting
  to the next 4am, with past times disallowed, and Hide / Cancel buttons.

### While hidden

- The overlay is hidden. Calendar polling carries on, so the countdown is
  current when it returns.
- The hide time is saved in `UserDefaults.app`, so it survives a quit, restart
  or reboot.
- When the hide time passes, the overlay returns where it was. The existing
  1-second state update notices, which also covers waking from sleep after
  the time has passed.

### Showing early

With the overlay hidden there is nothing to right-click, so the menu bar
popover shows "Hidden until <day> <time>" with a **Show now** button at the
top. The menu bar icon becomes `eye.slash` while hidden.

## Implementation

- `CountdownModel` gains a persisted `hiddenUntil: Date?`. `shouldShowOverlay`
  is false while `hiddenUntil` is in the future; `updateState()` clears it
  once it has passed. A helper computes the next 4am from a given date.
- `OverlayPanel` adds the two menu items and reports them through callbacks,
  matching `onSettings` / `onToggleCompact`.
- `AppDelegate` owns the picker window and wires the callbacks to the model.
- `SettingsView` shows the hidden banner and Show now button.
- `CountdownApp` swaps the menu bar icon while hidden.

## Out of scope

- Hiding from the menu bar popover.
- Preset durations (1 hour, end of day, etc.).

## Testing

Model tests for: next-4am calculation before and after 4am, hiding suppresses
the overlay, expiry restores it and clears the date, persistence across model
instances, and Show now clearing the date.
