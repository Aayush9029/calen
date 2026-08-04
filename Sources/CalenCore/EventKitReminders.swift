@preconcurrency import EventKit
import Foundation

private final class ReminderBatch: @unchecked Sendable {
  let values: [EKReminder]

  init(_ values: [EKReminder]) {
    self.values = values
  }
}

@MainActor
extension EventKitService {
  public func reminders(
    list: String?,
    search: String?,
    completed: Bool?,
    dueAfter: Date?,
    dueBefore: Date?,
    limit: Int?
  ) async throws -> [ReminderRecord] {
    try requireFullAccess(to: [.reminder])
    if let limit, limit <= 0 {
      throw CalenError.invalidInput("Limit must be greater than zero.")
    }
    if let dueAfter, let dueBefore, dueBefore < dueAfter {
      throw CalenError.invalidInput("--due-before must be after --due-after.")
    }

    let calendars = try list.map {
      [try resolveCalendar($0, entity: .reminder)]
    }
    var results = await fetchReminderRecords(calendars: calendars)
    if let search, !search.isEmpty {
      results = results.filter { reminderMatches($0, query: search) }
    }
    if let completed {
      results = results.filter { $0.isCompleted == completed }
    }
    if let dueAfter {
      results = results.filter {
        guard let date = $0.dueDate else { return false }
        return date >= dueAfter
      }
    }
    if let dueBefore {
      results = results.filter {
        guard let date = $0.dueDate else { return false }
        return date <= dueBefore
      }
    }
    results.sort { lhs, rhs in
      switch (lhs.dueDate, rhs.dueDate) {
      case (.some(let lhsDate), .some(let rhsDate)) where lhsDate != rhsDate:
        return lhsDate < rhsDate
      case (.some, .none):
        return true
      case (.none, .some):
        return false
      default:
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title)
          == .orderedAscending
      }
    }
    if let limit {
      results = Array(results.prefix(limit))
    }
    return results
  }

  public func reminder(_ selector: ReminderSelector) throws -> ReminderRecord {
    try requireFullAccess(to: [.reminder])
    return reminderRecord(try resolveReminder(selector))
  }

  public func createReminder(
    _ input: ReminderCreateInput,
    dryRun: Bool
  ) throws -> MutationRecord<ReminderRecord> {
    try requireFullAccess(to: [.reminder])
    try validatePriority(input.priority)
    if input.recurrence != nil, input.due == nil {
      throw CalenError.invalidInput("A recurring reminder requires --due.")
    }

    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = try ValueTools.requireNonempty(input.title, name: "Reminder title")
    reminder.calendar =
      try input.list.map {
        try resolveCalendar($0, entity: .reminder)
      } ?? eventStore.defaultCalendarForNewReminders()
    guard let list = reminder.calendar else {
      throw CalenError.notFound(
        "No default reminder list is available. Pass --list with an identifier."
      )
    }
    guard list.allowsContentModifications else {
      throw CalenError.readOnly("Reminder list “\(list.title)” is read-only.")
    }

    reminder.notes = input.notes
    reminder.url = input.url
    reminder.location = input.location
    reminder.startDateComponents = input.start.map(DateComponentsConverter.components)
    reminder.dueDateComponents = input.due.map(DateComponentsConverter.components)
    reminder.timeZone = input.due?.timeZone ?? input.start?.timeZone
    reminder.priority = input.priority
    reminder.alarms = input.alarms.map(makeAlarm)
    if let recurrence = input.recurrence {
      reminder.recurrenceRules = [makeRecurrenceRule(recurrence)]
    }

    if !dryRun {
      try eventStore.save(reminder, commit: true)
    }
    return MutationRecord(
      operation: "create",
      changed: true,
      dryRun: dryRun,
      value: reminderRecord(reminder)
    )
  }

  public func updateReminder(
    _ selector: ReminderSelector,
    input: ReminderUpdateInput,
    dryRun: Bool
  ) throws -> MutationRecord<ReminderRecord> {
    try requireFullAccess(to: [.reminder])
    let reminder = try resolveReminder(selector)
    guard reminder.calendar?.allowsContentModifications == true else {
      throw CalenError.readOnly("The reminder belongs to a read-only list.")
    }

    var changed = false
    if let title = input.title {
      let cleanTitle = try ValueTools.requireNonempty(title, name: "Reminder title")
      if reminder.title != cleanTitle {
        reminder.title = cleanTitle
        changed = true
      }
    }
    changed =
      applyString(input.notes, current: reminder.notes) {
        reminder.notes = $0
      } || changed
    changed =
      applyURL(input.url, current: reminder.url) {
        reminder.url = $0
      } || changed
    changed =
      applyString(input.location, current: reminder.location) {
        reminder.location = $0
      } || changed
    changed =
      applyDateComponents(
        input.start,
        current: reminder.startDateComponents
      ) {
        reminder.startDateComponents = $0
      } || changed
    changed =
      applyDateComponents(
        input.due,
        current: reminder.dueDateComponents
      ) {
        reminder.dueDateComponents = $0
      } || changed
    if case .set(let parsed) = input.due {
      changed = applyTimeZone(.set(parsed.timeZone), to: reminder) || changed
    } else if case .set(let parsed) = input.start {
      changed = applyTimeZone(.set(parsed.timeZone), to: reminder) || changed
    }
    if let priority = input.priority {
      try validatePriority(priority)
      if reminder.priority != priority {
        reminder.priority = priority
        changed = true
      }
    }
    changed = applyAlarms(input.alarms, to: reminder) || changed
    changed = applyRecurrence(input.recurrence, to: reminder) || changed

    if reminder.hasRecurrenceRules, reminder.dueDateComponents == nil {
      throw CalenError.invalidInput("A recurring reminder requires a due date.")
    }
    if changed, !dryRun {
      try eventStore.save(reminder, commit: true)
    }
    let record = reminderRecord(reminder)
    if dryRun {
      reminder.rollback()
    }
    return MutationRecord(
      operation: "update",
      changed: changed,
      dryRun: dryRun,
      value: record
    )
  }

  public func moveReminder(
    _ selector: ReminderSelector,
    list value: String,
    dryRun: Bool
  ) throws -> MutationRecord<ReminderRecord> {
    try requireFullAccess(to: [.reminder])
    let reminder = try resolveReminder(selector)
    let list = try resolveCalendar(value, entity: .reminder)
    guard list.allowsContentModifications else {
      throw CalenError.readOnly("Reminder list “\(list.title)” is read-only.")
    }

    let changed = reminder.calendar?.calendarIdentifier != list.calendarIdentifier
    if changed {
      reminder.calendar = list
      if !dryRun {
        try eventStore.save(reminder, commit: true)
      }
    }
    let record = reminderRecord(reminder)
    if dryRun {
      reminder.rollback()
    }
    return MutationRecord(
      operation: "move",
      changed: changed,
      dryRun: dryRun,
      value: record
    )
  }

  public func setReminderCompletion(
    _ selector: ReminderSelector,
    completed: Bool,
    completionDate: Date?,
    dryRun: Bool
  ) throws -> MutationRecord<ReminderRecord> {
    try requireFullAccess(to: [.reminder])
    let reminder = try resolveReminder(selector)
    guard reminder.calendar?.allowsContentModifications == true else {
      throw CalenError.readOnly("The reminder belongs to a read-only list.")
    }

    let changed: Bool
    if completed {
      if let completionDate {
        changed =
          reminder.completionDate != completionDate
          || !reminder.isCompleted
        if changed {
          reminder.completionDate = completionDate
        }
      } else {
        changed = !reminder.isCompleted
        if changed {
          reminder.isCompleted = true
        }
      }
    } else {
      changed = reminder.isCompleted || reminder.completionDate != nil
      if changed {
        reminder.isCompleted = false
      }
    }

    if changed, !dryRun {
      try eventStore.save(reminder, commit: true)
    }
    let record = reminderRecord(reminder)
    if dryRun {
      reminder.rollback()
    }
    return MutationRecord(
      operation: completed ? "complete" : "reopen",
      changed: changed,
      dryRun: dryRun,
      value: record
    )
  }

  public func deleteReminder(
    _ selector: ReminderSelector,
    dryRun: Bool
  ) throws -> MutationRecord<ReminderRecord> {
    try requireFullAccess(to: [.reminder])
    let reminder = try resolveReminder(selector)
    guard reminder.calendar?.allowsContentModifications == true else {
      throw CalenError.readOnly("The reminder belongs to a read-only list.")
    }
    let record = reminderRecord(reminder)
    if !dryRun {
      try eventStore.remove(reminder, commit: true)
    }
    return MutationRecord(
      operation: "delete",
      changed: true,
      dryRun: dryRun,
      value: record
    )
  }

  func fetchReminderRecords(calendars: [EKCalendar]?) async -> [ReminderRecord] {
    let predicate = eventStore.predicateForReminders(in: calendars)
    return await withCheckedContinuation { continuation in
      eventStore.fetchReminders(matching: predicate) { reminders in
        // EventKit invokes this callback on an arbitrary queue. The unchecked box
        // only carries the objects into the main-actor task that immediately maps them.
        let batch = ReminderBatch(reminders ?? [])
        Task { @MainActor in
          continuation.resume(returning: batch.values.map(self.reminderRecord))
        }
      }
    }
  }

  func resolveReminder(_ selector: ReminderSelector) throws -> EKReminder {
    if selector.externalIdentifier {
      let matches = eventStore.calendarItems(
        withExternalIdentifier: selector.identifier
      ).compactMap { $0 as? EKReminder }
      guard !matches.isEmpty else {
        throw CalenError.notFound(
          "No reminder has external identifier “\(selector.identifier)”."
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
    guard
      let reminder = eventStore.calendarItem(
        withIdentifier: selector.identifier
      ) as? EKReminder
    else {
      throw CalenError.notFound(
        "No reminder matches identifier “\(selector.identifier)”."
      )
    }
    return reminder
  }

  func reminderMatches(_ reminder: ReminderRecord, query: String) -> Bool {
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return [reminder.title, reminder.notes, reminder.location, reminder.url]
      .compactMap { $0 }
      .contains { $0.range(of: query, options: options) != nil }
  }

  func validatePriority(_ priority: Int) throws {
    guard (0...9).contains(priority) else {
      throw CalenError.invalidInput(
        "Reminder priority must be 0 through 9, where 1 is highest and 9 is lowest."
      )
    }
  }

  func applyDateComponents(
    _ change: FieldChange<ParsedDate>,
    current: DateComponents?,
    assign: (DateComponents?) -> Void
  ) -> Bool {
    switch change {
    case .unchanged:
      return false
    case .clear:
      guard current != nil else { return false }
      assign(nil)
      return true
    case .set(let parsed):
      let components = DateComponentsConverter.components(from: parsed)
      guard current != components else { return false }
      assign(components)
      return true
    }
  }
}
