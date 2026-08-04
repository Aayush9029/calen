@preconcurrency import EventKit
import Foundation

@MainActor
extension EventKitService {
  public func events(
    from: Date,
    to: Date,
    calendar: String?,
    search: String?,
    limit: Int?
  ) throws -> [EventRecord] {
    try requireFullAccess(to: [.event])
    guard to > from else {
      throw CalenError.invalidInput("The event range end must be after its start.")
    }
    guard to.timeIntervalSince(from) <= 366 * 4 * 86_400 else {
      throw CalenError.invalidInput("EventKit event queries cannot exceed four years.")
    }
    if let limit, limit <= 0 {
      throw CalenError.invalidInput("Limit must be greater than zero.")
    }

    let calendars = try calendar.map {
      [try resolveCalendar($0, entity: .event)]
    }
    let predicate = eventStore.predicateForEvents(
      withStart: from,
      end: to,
      calendars: calendars
    )
    var results = eventStore.events(matching: predicate)
    if let search, !search.isEmpty {
      results = results.filter { eventMatches($0, query: search) }
    }
    results.sort {
      if $0.startDate != $1.startDate {
        return $0.startDate < $1.startDate
      }
      return ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "")
        == .orderedAscending
    }
    if let limit {
      results = Array(results.prefix(limit))
    }
    return results.map(eventRecord)
  }

  public func event(_ selector: EventSelector) throws -> EventRecord {
    try requireFullAccess(to: [.event])
    return eventRecord(try resolveEvent(selector))
  }

  public func createEvent(
    _ input: EventCreateInput,
    dryRun: Bool
  ) throws -> MutationRecord<EventRecord> {
    try requireFullAccess(to: [.event])
    try validateEventDates(start: input.start.date, end: input.end.date)
    if input.allDay, !input.start.isDateOnly || !input.end.isDateOnly {
      throw CalenError.invalidInput(
        "All-day event start and end values must use YYYY-MM-DD."
      )
    }

    let event = EKEvent(eventStore: eventStore)
    event.title = try ValueTools.requireNonempty(input.title, name: "Event title")
    event.calendar =
      try input.calendar.map {
        try resolveCalendar($0, entity: .event)
      } ?? eventStore.defaultCalendarForNewEvents
    guard let calendar = event.calendar else {
      throw CalenError.notFound(
        "No default event calendar is available. Pass --calendar with an identifier."
      )
    }
    guard calendar.allowsContentModifications else {
      throw CalenError.readOnly("Calendar “\(calendar.title)” is read-only.")
    }

    event.startDate = input.start.date
    event.endDate = input.end.date
    event.isAllDay = input.allDay
    event.notes = input.notes
    event.url = input.url
    if let structuredLocation = input.structuredLocation {
      event.structuredLocation = makeStructuredLocation(structuredLocation)
    } else {
      event.location = input.location
    }
    event.timeZone = input.timeZone
    if let availability = input.availability {
      event.availability = self.availability(availability)
    }
    event.alarms = input.alarms.map(makeAlarm)
    if let recurrence = input.recurrence {
      event.recurrenceRules = [makeRecurrenceRule(recurrence)]
    }

    if !dryRun {
      try eventStore.save(event, span: .thisEvent, commit: true)
    }
    return MutationRecord(
      operation: "create",
      changed: true,
      dryRun: dryRun,
      value: eventRecord(event)
    )
  }

  public func updateEvent(
    _ selector: EventSelector,
    input: EventUpdateInput,
    span: EventSpan?,
    dryRun: Bool
  ) throws -> MutationRecord<EventRecord> {
    try requireFullAccess(to: [.event])
    let event = try resolveEvent(selector)
    guard event.calendar?.allowsContentModifications == true else {
      throw CalenError.readOnly("The event belongs to a read-only calendar.")
    }

    var changed = false
    if let title = input.title {
      let cleanTitle = try ValueTools.requireNonempty(title, name: "Event title")
      if event.title != cleanTitle {
        event.title = cleanTitle
        changed = true
      }
    }
    changed = applyString(input.notes, current: event.notes) { event.notes = $0 } || changed
    changed = applyURL(input.url, current: event.url) { event.url = $0 } || changed
    changed =
      applyString(input.location, current: event.location) { event.location = $0 } || changed
    changed =
      applyStructuredLocation(
        input.structuredLocation,
        to: event
      ) || changed
    changed = applyTimeZone(input.timeZone, to: event) || changed

    if let start = input.start, event.startDate != start.date {
      event.startDate = start.date
      changed = true
    }
    if let end = input.end, normalizedEndDate(event) != end.date {
      event.endDate = end.date
      changed = true
    }
    if let allDay = input.allDay, event.isAllDay != allDay {
      event.isAllDay = allDay
      changed = true
    }
    if let availability = input.availability {
      let value = self.availability(availability)
      if event.availability != value {
        event.availability = value
        changed = true
      }
    }
    changed = applyAlarms(input.alarms, to: event) || changed
    changed = applyRecurrence(input.recurrence, to: event) || changed

    try validateEventDates(start: event.startDate, end: event.endDate)
    if event.isAllDay {
      let zone = event.timeZone ?? .current
      let calendar = DateParser(timeZone: zone).calendar
      let startComponents = calendar.dateComponents(
        [.hour, .minute, .second],
        from: event.startDate
      )
      let endComponents = calendar.dateComponents(
        [.hour, .minute, .second],
        from: event.endDate
      )
      if startComponents.hour != 0 || startComponents.minute != 0
        || endComponents.hour != 0 || endComponents.minute != 0
      {
        throw CalenError.invalidInput(
          "All-day event dates must resolve to local midnight."
        )
      }
    }

    if changed {
      let resolvedSpan = try requireSpanIfRecurring(event, requested: span)
      if !dryRun {
        try eventStore.save(event, span: eventKitSpan(resolvedSpan), commit: true)
      }
    }
    let record = eventRecord(event)
    if dryRun {
      event.rollback()
    }
    return MutationRecord(
      operation: "update",
      changed: changed,
      dryRun: dryRun,
      value: record
    )
  }

  public func moveEvent(
    _ selector: EventSelector,
    calendar value: String,
    span: EventSpan?,
    dryRun: Bool
  ) throws -> MutationRecord<EventRecord> {
    try requireFullAccess(to: [.event])
    let event = try resolveEvent(selector)
    let calendar = try resolveCalendar(value, entity: .event)
    guard calendar.allowsContentModifications else {
      throw CalenError.readOnly("Calendar “\(calendar.title)” is read-only.")
    }

    let changed = event.calendar?.calendarIdentifier != calendar.calendarIdentifier
    if changed {
      event.calendar = calendar
      let resolvedSpan = try requireSpanIfRecurring(event, requested: span)
      if !dryRun {
        try eventStore.save(event, span: eventKitSpan(resolvedSpan), commit: true)
      }
    }
    let record = eventRecord(event)
    if dryRun {
      event.rollback()
    }
    return MutationRecord(
      operation: "move",
      changed: changed,
      dryRun: dryRun,
      value: record
    )
  }

  public func deleteEvent(
    _ selector: EventSelector,
    span: EventSpan?,
    dryRun: Bool
  ) throws -> MutationRecord<EventRecord> {
    try requireFullAccess(to: [.event])
    let event = try resolveEvent(selector)
    guard event.calendar?.allowsContentModifications == true else {
      throw CalenError.readOnly("The event belongs to a read-only calendar.")
    }
    let resolvedSpan = try requireSpanIfRecurring(event, requested: span)
    let record = eventRecord(event)
    if !dryRun {
      try eventStore.remove(event, span: eventKitSpan(resolvedSpan), commit: true)
    }
    return MutationRecord(
      operation: "delete",
      changed: true,
      dryRun: dryRun,
      value: record
    )
  }

  func resolveEvent(_ selector: EventSelector) throws -> EKEvent {
    if let occurrenceDate = selector.occurrenceDate {
      let start = occurrenceDate.addingTimeInterval(-86_400)
      let end = occurrenceDate.addingTimeInterval(86_400)
      let predicate = eventStore.predicateForEvents(
        withStart: start,
        end: end,
        calendars: nil
      )
      let matches = eventStore.events(matching: predicate).filter { event in
        let identifierMatches =
          selector.externalIdentifier
          ? event.calendarItemExternalIdentifier == selector.identifier
          : event.eventIdentifier == selector.identifier
            || event.calendarItemIdentifier == selector.identifier
        guard let date = event.occurrenceDate ?? event.startDate else {
          return false
        }
        return identifierMatches && abs(date.timeIntervalSince(occurrenceDate)) < 1
      }
      guard !matches.isEmpty else {
        throw CalenError.notFound(
          "No event occurrence matches the identifier and occurrence date."
        )
      }
      guard matches.count == 1 else {
        throw CalenError.ambiguous(
          selector.identifier,
          matches: matches.map {
            "\($0.title ?? "Untitled") at \($0.startDate.formatted(.iso8601))"
          }
        )
      }
      return matches[0]
    }

    if selector.externalIdentifier {
      let matches = eventStore.calendarItems(
        withExternalIdentifier: selector.identifier
      ).compactMap { $0 as? EKEvent }
      guard !matches.isEmpty else {
        throw CalenError.notFound(
          "No event has external identifier “\(selector.identifier)”."
        )
      }
      guard matches.count == 1 else {
        throw CalenError.ambiguous(
          selector.identifier,
          matches: matches.map {
            "\($0.title ?? "Untitled") in \($0.calendar?.title ?? "Unknown")"
          }
        )
      }
      return matches[0]
    }

    if let event = eventStore.event(withIdentifier: selector.identifier) {
      return event
    }
    if let event = eventStore.calendarItem(
      withIdentifier: selector.identifier
    ) as? EKEvent {
      return event
    }
    throw CalenError.notFound("No event matches identifier “\(selector.identifier)”.")
  }

  func eventMatches(_ event: EKEvent, query: String) -> Bool {
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return [event.title, event.notes, event.location, event.url?.absoluteString]
      .compactMap { $0 }
      .contains { $0.range(of: query, options: options) != nil }
  }

  func validateEventDates(start: Date, end: Date) throws {
    guard end > start else {
      throw CalenError.invalidInput("Event end must be after its start.")
    }
  }

  func requireSpanIfRecurring(
    _ event: EKEvent,
    requested: EventSpan?
  ) throws -> EventSpan {
    if event.hasRecurrenceRules || event.isDetached {
      guard let requested else {
        throw CalenError.invalidInput(
          "This event is recurring. Pass --span this or --span future explicitly."
        )
      }
      return requested
    }
    return requested ?? .this
  }

  func eventKitSpan(_ span: EventSpan) -> EKSpan {
    span == .this ? .thisEvent : .futureEvents
  }

  func applyString(
    _ change: FieldChange<String>,
    current: String?,
    assign: (String?) -> Void
  ) -> Bool {
    switch change {
    case .unchanged:
      return false
    case .set(let value):
      guard current != value else { return false }
      assign(value)
      return true
    case .clear:
      guard current != nil else { return false }
      assign(nil)
      return true
    }
  }

  func applyURL(
    _ change: FieldChange<URL>,
    current: URL?,
    assign: (URL?) -> Void
  ) -> Bool {
    switch change {
    case .unchanged:
      return false
    case .set(let value):
      guard current != value else { return false }
      assign(value)
      return true
    case .clear:
      guard current != nil else { return false }
      assign(nil)
      return true
    }
  }

  func applyStructuredLocation(
    _ change: FieldChange<StructuredLocationSpec>,
    to event: EKEvent
  ) -> Bool {
    switch change {
    case .unchanged:
      return false
    case .clear:
      guard event.structuredLocation != nil else { return false }
      event.structuredLocation = nil
      return true
    case .set(let spec):
      let desired = StructuredLocationRecord(
        title: spec.title,
        latitude: spec.latitude,
        longitude: spec.longitude,
        radiusMeters: spec.radiusMeters
      )
      guard structuredLocationRecord(event.structuredLocation) != desired else {
        return false
      }
      event.structuredLocation = makeStructuredLocation(spec)
      return true
    }
  }

  func applyTimeZone(
    _ change: FieldChange<TimeZone>,
    to item: EKCalendarItem
  ) -> Bool {
    switch change {
    case .unchanged:
      return false
    case .clear:
      guard item.timeZone != nil else { return false }
      item.timeZone = nil
      return true
    case .set(let value):
      guard item.timeZone?.identifier != value.identifier else { return false }
      item.timeZone = value
      return true
    }
  }

  func applyAlarms(
    _ change: FieldChange<[AlarmSpec]>,
    to item: EKCalendarItem
  ) -> Bool {
    switch change {
    case .unchanged:
      return false
    case .clear:
      guard !(item.alarms ?? []).isEmpty else { return false }
      item.alarms = nil
      return true
    case .set(let specs):
      let alarms = specs.map(makeAlarm)
      let existing = (item.alarms ?? []).map(alarmRecord)
      let desired = alarms.map(alarmRecord)
      guard existing != desired else { return false }
      item.alarms = alarms
      return true
    }
  }

  func applyRecurrence(
    _ change: FieldChange<RecurrenceSpec>,
    to item: EKCalendarItem
  ) -> Bool {
    switch change {
    case .unchanged:
      return false
    case .clear:
      guard !(item.recurrenceRules ?? []).isEmpty else { return false }
      item.recurrenceRules = nil
      return true
    case .set(let spec):
      let rule = makeRecurrenceRule(spec)
      let existing = (item.recurrenceRules ?? []).map(recurrenceRecord)
      let desired = [recurrenceRecord(rule)]
      guard existing != desired else { return false }
      item.recurrenceRules = [rule]
      return true
    }
  }
}
