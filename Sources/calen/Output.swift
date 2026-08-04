import CalenCore
import Foundation

enum Output {
  static func json<Value: Encodable>(_ value: Value) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
  }

  static func authorization(_ value: AuthorizationRecord, json: Bool) throws {
    if json {
      try self.json(value)
      return
    }
    print("Calendars: \(value.events.rawValue)")
    print("Reminders: \(value.reminders.rawValue)")
  }

  static func diagnostics(_ value: DiagnosticRecord, json: Bool) throws {
    if json {
      try self.json(value)
      return
    }
    print("Binary: \(value.binaryPath)")
    print("Bundle identifier: \(value.bundleIdentifier ?? "missing")")
    print("Calendar usage description: \(yesNo(value.calendarUsageDescriptionEmbedded))")
    print("Reminders usage description: \(yesNo(value.remindersUsageDescriptionEmbedded))")
    print("Calendars access: \(value.authorization.events.rawValue)")
    print("Reminders access: \(value.authorization.reminders.rawValue)")
    print("Travel time: \(value.travelTimeAPI)")
    print("macOS: \(value.macOSVersion)")
  }

  static func sources(_ values: [SourceRecord], json: Bool) throws {
    if json {
      try self.json(values)
      return
    }
    guard !values.isEmpty else {
      print("No calendar sources found.")
      return
    }
    for value in values {
      print(
        "\(value.identifier)\t\(value.title)\t\(value.type)\t"
          + "\(value.eventCalendarCount) calendars, \(value.reminderListCount) lists"
      )
    }
  }

  static func source(_ value: SourceRecord, json: Bool) throws {
    if json {
      try self.json(value)
      return
    }
    print("Identifier: \(value.identifier)")
    print("Title: \(value.title)")
    print("Type: \(value.type)")
    print("Delegate: \(yesNo(value.isDelegate))")
    print("Calendars: \(value.eventCalendarCount)")
    print("Reminder lists: \(value.reminderListCount)")
  }

  static func collections(_ values: [CollectionRecord], json: Bool) throws {
    if json {
      try self.json(values)
      return
    }
    guard !values.isEmpty else {
      print("No collections found.")
      return
    }
    for value in values {
      let defaultMark = value.isDefault ? " default" : ""
      print(
        "\(value.identifier ?? "-")\t\(value.title)\t"
          + "\(value.color ?? "-")\t\(value.sourceTitle ?? "-")\(defaultMark)"
      )
    }
  }

  static func collection(_ value: CollectionRecord, json: Bool) throws {
    if json {
      try self.json(value)
      return
    }
    print("Identifier: \(value.identifier ?? "not saved")")
    print("Title: \(value.title)")
    print("Entity: \(value.entity.rawValue)")
    print("Color: \(value.color ?? "none")")
    print("Type: \(value.type)")
    print("Source: \(value.sourceTitle ?? "none")")
    print("Source identifier: \(value.sourceIdentifier ?? "none")")
    print("Default: \(yesNo(value.isDefault))")
    print("Writable items: \(yesNo(value.allowsContentModifications))")
    print("Immutable collection: \(yesNo(value.isImmutable))")
    if !value.supportedAvailabilities.isEmpty {
      print("Availability: \(value.supportedAvailabilities.joined(separator: ", "))")
    }
  }

  static func events(_ values: [EventRecord], json: Bool) throws {
    if json {
      try self.json(values)
      return
    }
    guard !values.isEmpty else {
      print("No events found.")
      return
    }
    for value in values {
      let occurrence =
        value.occurrenceDate.map {
          " occurrence=\(iso8601($0))"
        } ?? ""
      print(
        "\(iso8601(value.startDate))\t\(value.identifier ?? "-")\t"
          + "\(value.title)\t\(value.calendarTitle ?? "-")\(occurrence)"
      )
    }
  }

  static func event(_ value: EventRecord, json: Bool) throws {
    if json {
      try self.json(value)
      return
    }
    print("Identifier: \(value.identifier ?? "not saved")")
    print("External identifier: \(value.externalIdentifier ?? "none")")
    print("Title: \(value.title)")
    print("Calendar: \(value.calendarTitle ?? "none")")
    print("Start: \(iso8601(value.startDate))")
    print("End: \(iso8601(value.endDate))")
    print("All day: \(yesNo(value.isAllDay))")
    print("Time zone: \(value.timeZone ?? "floating")")
    print("Location: \(value.location ?? "none")")
    print("URL: \(value.url ?? "none")")
    print("Notes: \(value.notes ?? "none")")
    print("Availability: \(value.availability)")
    print("Status: \(value.status) (read-only)")
    print("Detached: \(yesNo(value.isDetached)) (read-only)")
    print("Alarms: \(value.alarms.count)")
    print("Recurrence rules: \(value.recurrenceRules.count)")
    print("Organizer: \(value.organizer?.name ?? "none") (read-only)")
    print("Attendees: \(value.attendees.count) (read-only)")
    print("Created: \(value.creationDate.map(iso8601) ?? "unknown") (read-only)")
    print("Modified: \(value.lastModifiedDate.map(iso8601) ?? "unknown") (read-only)")
    print("Travel time: unavailable in public EventKit")
  }

  static func reminders(_ values: [ReminderRecord], json: Bool) throws {
    if json {
      try self.json(values)
      return
    }
    guard !values.isEmpty else {
      print("No reminders found.")
      return
    }
    for value in values {
      let state = value.isCompleted ? "completed" : "open"
      let due = value.dueDate.map(iso8601) ?? "no due date"
      print(
        "\(due)\t\(value.identifier ?? "-")\t\(value.title)\t"
          + "\(value.listTitle ?? "-")\t\(state)"
      )
    }
  }

  static func reminder(_ value: ReminderRecord, json: Bool) throws {
    if json {
      try self.json(value)
      return
    }
    print("Identifier: \(value.identifier ?? "not saved")")
    print("External identifier: \(value.externalIdentifier ?? "none")")
    print("Title: \(value.title)")
    print("List: \(value.listTitle ?? "none")")
    print("Start: \(value.startDate.map(iso8601) ?? "none")")
    print("Due: \(value.dueDate.map(iso8601) ?? "none")")
    print("Completed: \(yesNo(value.isCompleted))")
    print("Completion date: \(value.completionDate.map(iso8601) ?? "none")")
    print("Priority: \(value.priority)")
    print("Location: \(value.location ?? "none")")
    print("URL: \(value.url ?? "none")")
    print("Notes: \(value.notes ?? "none")")
    print("Alarms: \(value.alarms.count)")
    print("Recurrence rules: \(value.recurrenceRules.count)")
    print("Attendees: \(value.attendees.count) (read-only)")
    print("Created: \(value.creationDate.map(iso8601) ?? "unknown") (read-only)")
    print("Modified: \(value.lastModifiedDate.map(iso8601) ?? "unknown") (read-only)")
  }

  static func mutation<Value: Codable & Sendable>(
    _ value: MutationRecord<Value>,
    json: Bool,
    describe: (Value) -> String
  ) throws {
    if json {
      try self.json(value)
      return
    }
    let prefix = value.dryRun ? "Dry run" : value.changed ? "Done" : "No changes"
    print("\(prefix): \(value.operation) \(describe(value.value))")
  }

  static func yesNo(_ value: Bool) -> String {
    value ? "yes" : "no"
  }

  static func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }
}
