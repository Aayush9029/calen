# EventKit behavior

calen targets macOS 14 because full read and write access uses `requestFullAccessToEvents()` and `requestFullAccessToReminders()`, introduced in macOS 14. Its executable embeds `NSCalendarsFullAccessUsageDescription` and `NSRemindersFullAccessUsageDescription`, links EventKit, and is distributed with the stable `art.aayush.calen` signing identifier.

## Writable data

EventKit allows calen to create, update, move, and remove calendars, reminder lists, events, and reminders when their account and collection permit changes.

Writable event data includes title, notes, URL, location, structured location, time zone, all-day behavior, start, end, availability, alarms, recurrence, and calendar assignment. Event availability is accepted only when the destination calendar advertises support.

Writable reminder data includes title, notes, URL, start, due, completion state and date, priority, alarms, recurrence, and list assignment. Location alarm support is controlled by the reminder account. A recurring reminder requires a due date.

Calendar and reminder list titles and colors are writable unless EventKit marks the collection immutable. A source is selected only when the collection is created. EventKit does not allow moving an existing collection between sources. Default calendars and reminder lists are reported but cannot be changed through public EventKit.

## Read-only and unavailable data

calen reports organizers, attendees, attendee roles and participation status, event status, detached state, creation date, last modified date, source type, subscription state, and collection capabilities as read-only metadata.

Public EventKit does not provide third-party mutation APIs for attendees, organizers, invitations, participation responses, event status, creation dates, or modification dates. It also does not expose Calendar travel time on `EKEvent`. calen does not simulate any of these fields.

Procedure alarm URLs cannot be created or modified on modern macOS. calen supports relative, absolute, and geofence alarms. EventKit providers may reject or normalize alarms they do not support.

## Identifiers and recurring events

`eventIdentifier` and `calendarItemIdentifier` are convenient local identifiers, but EventKit documents that sync or a calendar move can change them. `calendarItemExternalIdentifier` comes from the server and is useful across devices, but it is not guaranteed to be unique in one store. calen exposes both and can resolve external identifiers with `--external-id`.

Event queries return one event per occurrence. Recurring occurrences share an external identifier, so list and JSON output include the original `occurrenceDate`. Pass `--occurrence` with the identifier to target one occurrence.

Updates, moves, and removals of recurring events require `--span this` or `--span future`. Updating one occurrence with `--span this` creates a detached occurrence when EventKit supports it. Reminders do not use `EKSpan`; their recurrence rule belongs to the reminder item.

## Dates and colors

ISO 8601 values with `Z` or an explicit offset identify an instant. Local values use `--time-zone` or the current system time zone. Date-only values use `YYYY-MM-DD`. calen rejects local times that do not exist during a daylight-saving transition.

All-day output uses an exclusive midnight end date even when EventKit internally persists the final second of the preceding day. This keeps durations and automation predictable.

Calendar providers may slightly normalize colors. calen compares persisted colors with a small component tolerance and reports the normalized hexadecimal value returned by EventKit.
