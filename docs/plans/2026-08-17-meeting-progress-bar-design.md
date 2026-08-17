# Time left in the current meeting

A setting that shows how much of the meeting you are *in* is left, as a
horizontal bar under the countdown dot with the minutes remaining beside it.
Off by default.

## What "the current meeting" means

The event that has started and not yet ended. This is independent of the dot,
which counts down to the *next* event. During a 10:00–11:00 standup with the
next meeting at 11:30, the dot goes grey at 10:05 (nothing upcoming within its
60-minute window) while the bar keeps draining until 11:00.

When two meetings overlap, the bar tracks the one ending soonest — that is the
one you have to leave first.

An event only qualifies if the dot would have counted down to it: the
meetings-only, hide declined/cancelled, hide tasks & birthdays and hide focus
time filters all apply, and a dismissed event gets no bar.

## Model

`CountdownModel` keeps the event list that `setEvents(_:)` previously discarded,
because a meeting can start between the 60-second polls and the bar has to
notice within the second. `updateState()`, already running every second, then
derives:

- `currentEvent` — the qualifying event where `start ≤ now < end`
- `meetingMinutesRemaining` — `ceil` of the minutes left, matching how the dot rounds
- `meetingProgress` — `remaining / duration`: 1.0 at the start, 0 at the end
- `isShowingMeetingProgress` — the setting is on *and* there is a current event

`isShowingMeetingProgress` is only written when the value changes, so the
panel-resize observer in `AppDelegate` does not fire every second.

The four filters existed twice, in `CalendarManager.fetchEvents` and again in
`updateState` (so a settings toggle takes effect before the next poll). They
move into one `passesFilters(_:)` on the model that all three callers share.

No Calendar API change: `fetchEvents` asks for `now … now+60min`, and Google
returns any event overlapping that window, including one that started three
hours ago.

## Appearance

The bar drains rather than fills, so its length always matches the number
beside it, and it drains in the same direction as the ring around the dot. It
is neutral white — colour meaning stays with the dot.

Standard mode puts it between the dot and the event details box:

```
        ●
  ▓▓▓▓▓░░░░░  30
 ┌──────────────┐
 │ Sprint plan. │
 └──────────────┘
```

Compact mode becomes two rows, and the background switches from a capsule to a
rounded rectangle — at that height a capsule's rounded ends are semicircles that
waste horizontal space. The bar is a fixed 72pt so its fill fraction stays
comparable minute to minute regardless of the event title's length:

```
╭────────────────────────────────╮
│ ● 12  Sprint planning – 10:30  │
│ ▓▓▓▓▓░░░░ 30                   │
╰────────────────────────────────╯
```

`OverlayLayoutState` gains a `showsMeetingProgress` field so the measurement
cache keys bar-visible and bar-hidden layouts separately and the panel resizes
instead of clipping.

## Settings

A "Show time left in current meeting" toggle in the Display section, under
"Event details".
