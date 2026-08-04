import Foundation

public enum EventSpan: String, Codable, CaseIterable, Sendable {
  case this
  case future
}

public enum EventAvailabilityValue: String, Codable, CaseIterable, Sendable {
  case busy
  case free
  case tentative
  case unavailable
}

public struct EventSelector: Equatable, Sendable {
  public let identifier: String
  public let externalIdentifier: Bool
  public let occurrenceDate: Date?

  public init(
    identifier: String,
    externalIdentifier: Bool = false,
    occurrenceDate: Date? = nil
  ) {
    self.identifier = identifier
    self.externalIdentifier = externalIdentifier
    self.occurrenceDate = occurrenceDate
  }
}

public struct EventCreateInput: Sendable {
  public let title: String
  public let calendar: String?
  public let start: ParsedDate
  public let end: ParsedDate
  public let allDay: Bool
  public let notes: String?
  public let url: URL?
  public let location: String?
  public let structuredLocation: StructuredLocationSpec?
  public let timeZone: TimeZone?
  public let availability: EventAvailabilityValue?
  public let alarms: [AlarmSpec]
  public let recurrence: RecurrenceSpec?

  public init(
    title: String,
    calendar: String?,
    start: ParsedDate,
    end: ParsedDate,
    allDay: Bool,
    notes: String?,
    url: URL?,
    location: String?,
    structuredLocation: StructuredLocationSpec?,
    timeZone: TimeZone?,
    availability: EventAvailabilityValue?,
    alarms: [AlarmSpec],
    recurrence: RecurrenceSpec?
  ) {
    self.title = title
    self.calendar = calendar
    self.start = start
    self.end = end
    self.allDay = allDay
    self.notes = notes
    self.url = url
    self.location = location
    self.structuredLocation = structuredLocation
    self.timeZone = timeZone
    self.availability = availability
    self.alarms = alarms
    self.recurrence = recurrence
  }
}

public struct EventUpdateInput: Sendable {
  public var title: String?
  public var notes: FieldChange<String>
  public var url: FieldChange<URL>
  public var location: FieldChange<String>
  public var structuredLocation: FieldChange<StructuredLocationSpec>
  public var timeZone: FieldChange<TimeZone>
  public var start: ParsedDate?
  public var end: ParsedDate?
  public var allDay: Bool?
  public var availability: EventAvailabilityValue?
  public var alarms: FieldChange<[AlarmSpec]>
  public var recurrence: FieldChange<RecurrenceSpec>

  public init(
    title: String? = nil,
    notes: FieldChange<String> = .unchanged,
    url: FieldChange<URL> = .unchanged,
    location: FieldChange<String> = .unchanged,
    structuredLocation: FieldChange<StructuredLocationSpec> = .unchanged,
    timeZone: FieldChange<TimeZone> = .unchanged,
    start: ParsedDate? = nil,
    end: ParsedDate? = nil,
    allDay: Bool? = nil,
    availability: EventAvailabilityValue? = nil,
    alarms: FieldChange<[AlarmSpec]> = .unchanged,
    recurrence: FieldChange<RecurrenceSpec> = .unchanged
  ) {
    self.title = title
    self.notes = notes
    self.url = url
    self.location = location
    self.structuredLocation = structuredLocation
    self.timeZone = timeZone
    self.start = start
    self.end = end
    self.allDay = allDay
    self.availability = availability
    self.alarms = alarms
    self.recurrence = recurrence
  }
}

public struct ReminderSelector: Equatable, Sendable {
  public let identifier: String
  public let externalIdentifier: Bool

  public init(identifier: String, externalIdentifier: Bool = false) {
    self.identifier = identifier
    self.externalIdentifier = externalIdentifier
  }
}

public struct ReminderCreateInput: Sendable {
  public let title: String
  public let list: String?
  public let notes: String?
  public let url: URL?
  public let location: String?
  public let start: ParsedDate?
  public let due: ParsedDate?
  public let priority: Int
  public let alarms: [AlarmSpec]
  public let recurrence: RecurrenceSpec?

  public init(
    title: String,
    list: String?,
    notes: String?,
    url: URL?,
    location: String?,
    start: ParsedDate?,
    due: ParsedDate?,
    priority: Int,
    alarms: [AlarmSpec],
    recurrence: RecurrenceSpec?
  ) {
    self.title = title
    self.list = list
    self.notes = notes
    self.url = url
    self.location = location
    self.start = start
    self.due = due
    self.priority = priority
    self.alarms = alarms
    self.recurrence = recurrence
  }
}

public struct ReminderUpdateInput: Sendable {
  public var title: String?
  public var notes: FieldChange<String>
  public var url: FieldChange<URL>
  public var location: FieldChange<String>
  public var start: FieldChange<ParsedDate>
  public var due: FieldChange<ParsedDate>
  public var priority: Int?
  public var alarms: FieldChange<[AlarmSpec]>
  public var recurrence: FieldChange<RecurrenceSpec>

  public init(
    title: String? = nil,
    notes: FieldChange<String> = .unchanged,
    url: FieldChange<URL> = .unchanged,
    location: FieldChange<String> = .unchanged,
    start: FieldChange<ParsedDate> = .unchanged,
    due: FieldChange<ParsedDate> = .unchanged,
    priority: Int? = nil,
    alarms: FieldChange<[AlarmSpec]> = .unchanged,
    recurrence: FieldChange<RecurrenceSpec> = .unchanged
  ) {
    self.title = title
    self.notes = notes
    self.url = url
    self.location = location
    self.start = start
    self.due = due
    self.priority = priority
    self.alarms = alarms
    self.recurrence = recurrence
  }
}
