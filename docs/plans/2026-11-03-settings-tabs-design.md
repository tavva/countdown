# Settings pop-up: tabbed redesign

The menu-bar settings pop-up had grown to about 1000pt tall: a single
scrolling column of segmented pickers, ragged switches and a nested calendar
list. This redesign splits it into four tabs at a fixed size.

Mock-ups (direction C): https://claude.ai/artifact/P5fLzphUresi61qzUpqequ

## Layout

Fixed 340 × ~500pt on every tab, so the pop-up never changes size when
switching tabs.

1. **Header** (always): the app icon (`NSApp.applicationIconImage`, 28pt),
   "Countdown", and a status line with a dot: green "Google Calendar
   connected" or grey "Not connected".
2. **Banners** (when relevant, above the tabs so they show on every tab):
   "Hidden until …" with "Show now"; the error banner.
3. **Tab bar**: four equal icon-over-label buttons: Circle, Events, Calendars,
   General. The selected tab has a light fill.
4. **Tab content**, in grouped rounded cards: label left, control right, inset
   separators between rows.
5. **Footer** (always): version on the left, "Quit ⌘Q" on the right.

## Tabs

- **Circle**: Size pop-up menu (Standard / Compact / Auto) with a caption
  explaining Auto (replaces the ? popover); Show event details (switch);
  Show time left in meeting; Move when displays change; when that is on, a
  "To corner" row with a small screen drawing whose four corners are buttons.
- **Events**: "Count down to" pop-up (All events / Meetings only) with the
  caption "Meetings are events with at least one other guest."; Skip declined
  & cancelled; Skip tasks & birthdays; Skip focus time.
- **Calendars**: one card listing calendars with colour dot, name and
  checkbox; enabled calendars sort first; the list scrolls inside the card.
- **General**: Open at login; Updates → "Check now"; Account card (Google
  Calendar, Connected, Disconnect); the Google trademark line.

## States

- **Signed out**: header, a short explanation, the existing Sign in with
  Google button, trademark line and footer. No tabs; shorter pop-up.
- **No Config.plist**: the existing setup notice takes the sign-in button's
  place.
- The last selected tab is remembered in `UserDefaults.app`.

## Labels

Renamed for brevity: "Hide …" → "Skip …", "Auto-reposition on display
change" → "Move when displays change", "Launch at login" → "Open at login",
"Show countdown for" → "Count down to".

## Out of scope

No setting, binding or stored key changes. Light mode comes from system
colours rather than a separate design.

## Verification

`--preview-settings` gains `PREVIEW_TAB=circle|events|calendars|general` so
each tab can be screenshotted with every `PREVIEW_STATE`.
