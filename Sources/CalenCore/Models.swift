import Foundation

public enum EntityKind: String, Codable, CaseIterable, Sendable {
  case event
  case reminder

  public var displayName: String {
    switch self {
    case .event: "Calendars"
    case .reminder: "Reminders"
    }
  }
}

public enum AccessStatus: String, Codable, Sendable {
  case notDetermined
  case restricted
  case denied
  case writeOnly
  case fullAccess
  case unknown
}

public struct AuthorizationRecord: Codable, Equatable, Sendable {
  public let events: AccessStatus
  public let reminders: AccessStatus

  public init(events: AccessStatus, reminders: AccessStatus) {
    self.events = events
    self.reminders = reminders
  }
}

public struct DiagnosticRecord: Codable, Equatable, Sendable {
  public let authorization: AuthorizationRecord
  public let bundleIdentifier: String?
  public let binaryPath: String
  public let calendarUsageDescriptionEmbedded: Bool
  public let remindersUsageDescriptionEmbedded: Bool
  public let macOSVersion: String
  public let eventStoreIdentifier: String
  public let travelTimeAPI: String

  public init(
    authorization: AuthorizationRecord,
    bundleIdentifier: String?,
    binaryPath: String,
    calendarUsageDescriptionEmbedded: Bool,
    remindersUsageDescriptionEmbedded: Bool,
    macOSVersion: String,
    eventStoreIdentifier: String,
    travelTimeAPI: String
  ) {
    self.authorization = authorization
    self.bundleIdentifier = bundleIdentifier
    self.binaryPath = binaryPath
    self.calendarUsageDescriptionEmbedded = calendarUsageDescriptionEmbedded
    self.remindersUsageDescriptionEmbedded = remindersUsageDescriptionEmbedded
    self.macOSVersion = macOSVersion
    self.eventStoreIdentifier = eventStoreIdentifier
    self.travelTimeAPI = travelTimeAPI
  }
}

public struct SourceRecord: Codable, Equatable, Sendable {
  public let identifier: String
  public let title: String
  public let type: String
  public let isDelegate: Bool
  public let eventCalendarCount: Int
  public let reminderListCount: Int

  public init(
    identifier: String,
    title: String,
    type: String,
    isDelegate: Bool,
    eventCalendarCount: Int,
    reminderListCount: Int
  ) {
    self.identifier = identifier
    self.title = title
    self.type = type
    self.isDelegate = isDelegate
    self.eventCalendarCount = eventCalendarCount
    self.reminderListCount = reminderListCount
  }
}

public struct CollectionRecord: Codable, Equatable, Sendable {
  public let identifier: String?
  public let entity: EntityKind
  public let title: String
  public let color: String?
  public let type: String
  public let sourceIdentifier: String?
  public let sourceTitle: String?
  public let sourceType: String?
  public let allowsContentModifications: Bool
  public let isImmutable: Bool
  public let isSubscribed: Bool
  public let isDefault: Bool
  public let allowedEntityTypes: [String]
  public let supportedAvailabilities: [String]

  public init(
    identifier: String?,
    entity: EntityKind,
    title: String,
    color: String?,
    type: String,
    sourceIdentifier: String?,
    sourceTitle: String?,
    sourceType: String?,
    allowsContentModifications: Bool,
    isImmutable: Bool,
    isSubscribed: Bool,
    isDefault: Bool,
    allowedEntityTypes: [String],
    supportedAvailabilities: [String]
  ) {
    self.identifier = identifier
    self.entity = entity
    self.title = title
    self.color = color
    self.type = type
    self.sourceIdentifier = sourceIdentifier
    self.sourceTitle = sourceTitle
    self.sourceType = sourceType
    self.allowsContentModifications = allowsContentModifications
    self.isImmutable = isImmutable
    self.isSubscribed = isSubscribed
    self.isDefault = isDefault
    self.allowedEntityTypes = allowedEntityTypes
    self.supportedAvailabilities = supportedAvailabilities
  }
}

public struct StructuredLocationRecord: Codable, Equatable, Sendable {
  public let title: String?
  public let latitude: Double?
  public let longitude: Double?
  public let radiusMeters: Double

  public init(
    title: String?,
    latitude: Double?,
    longitude: Double?,
    radiusMeters: Double
  ) {
    self.title = title
    self.latitude = latitude
    self.longitude = longitude
    self.radiusMeters = radiusMeters
  }
}

public struct AlarmRecord: Codable, Equatable, Sendable {
  public let type: String
  public let relativeOffsetSeconds: Double?
  public let absoluteDate: Date?
  public let proximity: String
  public let structuredLocation: StructuredLocationRecord?
  public let emailAddress: String?
  public let soundName: String?

  public init(
    type: String,
    relativeOffsetSeconds: Double?,
    absoluteDate: Date?,
    proximity: String,
    structuredLocation: StructuredLocationRecord?,
    emailAddress: String?,
    soundName: String?
  ) {
    self.type = type
    self.relativeOffsetSeconds = relativeOffsetSeconds
    self.absoluteDate = absoluteDate
    self.proximity = proximity
    self.structuredLocation = structuredLocation
    self.emailAddress = emailAddress
    self.soundName = soundName
  }
}

public struct RecurrenceWeekdayRecord: Codable, Equatable, Sendable {
  public let weekday: String
  public let weekNumber: Int

  public init(weekday: String, weekNumber: Int) {
    self.weekday = weekday
    self.weekNumber = weekNumber
  }
}

public struct RecurrenceEndRecord: Codable, Equatable, Sendable {
  public let date: Date?
  public let occurrenceCount: Int?

  public init(date: Date?, occurrenceCount: Int?) {
    self.date = date
    self.occurrenceCount = occurrenceCount
  }
}

public struct RecurrenceRecord: Codable, Equatable, Sendable {
  public let frequency: String
  public let interval: Int
  public let daysOfWeek: [RecurrenceWeekdayRecord]
  public let daysOfMonth: [Int]
  public let monthsOfYear: [Int]
  public let weeksOfYear: [Int]
  public let daysOfYear: [Int]
  public let setPositions: [Int]
  public let firstDayOfWeek: Int
  public let end: RecurrenceEndRecord?

  public init(
    frequency: String,
    interval: Int,
    daysOfWeek: [RecurrenceWeekdayRecord],
    daysOfMonth: [Int],
    monthsOfYear: [Int],
    weeksOfYear: [Int],
    daysOfYear: [Int],
    setPositions: [Int],
    firstDayOfWeek: Int,
    end: RecurrenceEndRecord?
  ) {
    self.frequency = frequency
    self.interval = interval
    self.daysOfWeek = daysOfWeek
    self.daysOfMonth = daysOfMonth
    self.monthsOfYear = monthsOfYear
    self.weeksOfYear = weeksOfYear
    self.daysOfYear = daysOfYear
    self.setPositions = setPositions
    self.firstDayOfWeek = firstDayOfWeek
    self.end = end
  }
}

public struct ParticipantRecord: Codable, Equatable, Sendable {
  public let name: String?
  public let url: String
  public let role: String
  public let type: String
  public let status: String
  public let isCurrentUser: Bool

  public init(
    name: String?,
    url: String,
    role: String,
    type: String,
    status: String,
    isCurrentUser: Bool
  ) {
    self.name = name
    self.url = url
    self.role = role
    self.type = type
    self.status = status
    self.isCurrentUser = isCurrentUser
  }
}

public struct EventRecord: Codable, Equatable, Sendable {
  public let identifier: String?
  public let calendarItemIdentifier: String?
  public let externalIdentifier: String?
  public let title: String
  public let notes: String?
  public let url: String?
  public let location: String?
  public let structuredLocation: StructuredLocationRecord?
  public let timeZone: String?
  public let isAllDay: Bool
  public let startDate: Date
  public let endDate: Date
  public let availability: String
  public let status: String
  public let calendarIdentifier: String?
  public let calendarTitle: String?
  public let occurrenceDate: Date?
  public let isDetached: Bool
  public let hasRecurrenceRules: Bool
  public let alarms: [AlarmRecord]
  public let recurrenceRules: [RecurrenceRecord]
  public let organizer: ParticipantRecord?
  public let attendees: [ParticipantRecord]
  public let creationDate: Date?
  public let lastModifiedDate: Date?
  public let travelTimeSeconds: Double?
  public let travelTimeWritable: Bool

  public init(
    identifier: String?,
    calendarItemIdentifier: String?,
    externalIdentifier: String?,
    title: String,
    notes: String?,
    url: String?,
    location: String?,
    structuredLocation: StructuredLocationRecord?,
    timeZone: String?,
    isAllDay: Bool,
    startDate: Date,
    endDate: Date,
    availability: String,
    status: String,
    calendarIdentifier: String?,
    calendarTitle: String?,
    occurrenceDate: Date?,
    isDetached: Bool,
    hasRecurrenceRules: Bool,
    alarms: [AlarmRecord],
    recurrenceRules: [RecurrenceRecord],
    organizer: ParticipantRecord?,
    attendees: [ParticipantRecord],
    creationDate: Date?,
    lastModifiedDate: Date?,
    travelTimeSeconds: Double?,
    travelTimeWritable: Bool
  ) {
    self.identifier = identifier
    self.calendarItemIdentifier = calendarItemIdentifier
    self.externalIdentifier = externalIdentifier
    self.title = title
    self.notes = notes
    self.url = url
    self.location = location
    self.structuredLocation = structuredLocation
    self.timeZone = timeZone
    self.isAllDay = isAllDay
    self.startDate = startDate
    self.endDate = endDate
    self.availability = availability
    self.status = status
    self.calendarIdentifier = calendarIdentifier
    self.calendarTitle = calendarTitle
    self.occurrenceDate = occurrenceDate
    self.isDetached = isDetached
    self.hasRecurrenceRules = hasRecurrenceRules
    self.alarms = alarms
    self.recurrenceRules = recurrenceRules
    self.organizer = organizer
    self.attendees = attendees
    self.creationDate = creationDate
    self.lastModifiedDate = lastModifiedDate
    self.travelTimeSeconds = travelTimeSeconds
    self.travelTimeWritable = travelTimeWritable
  }
}

public struct ReminderRecord: Codable, Equatable, Sendable {
  public let identifier: String?
  public let externalIdentifier: String?
  public let title: String
  public let notes: String?
  public let url: String?
  public let location: String?
  public let timeZone: String?
  public let listIdentifier: String?
  public let listTitle: String?
  public let startDate: Date?
  public let startDateIsDateOnly: Bool
  public let dueDate: Date?
  public let dueDateIsDateOnly: Bool
  public let isCompleted: Bool
  public let completionDate: Date?
  public let priority: Int
  public let alarms: [AlarmRecord]
  public let recurrenceRules: [RecurrenceRecord]
  public let attendees: [ParticipantRecord]
  public let creationDate: Date?
  public let lastModifiedDate: Date?

  public init(
    identifier: String?,
    externalIdentifier: String?,
    title: String,
    notes: String?,
    url: String?,
    location: String?,
    timeZone: String?,
    listIdentifier: String?,
    listTitle: String?,
    startDate: Date?,
    startDateIsDateOnly: Bool,
    dueDate: Date?,
    dueDateIsDateOnly: Bool,
    isCompleted: Bool,
    completionDate: Date?,
    priority: Int,
    alarms: [AlarmRecord],
    recurrenceRules: [RecurrenceRecord],
    attendees: [ParticipantRecord],
    creationDate: Date?,
    lastModifiedDate: Date?
  ) {
    self.identifier = identifier
    self.externalIdentifier = externalIdentifier
    self.title = title
    self.notes = notes
    self.url = url
    self.location = location
    self.timeZone = timeZone
    self.listIdentifier = listIdentifier
    self.listTitle = listTitle
    self.startDate = startDate
    self.startDateIsDateOnly = startDateIsDateOnly
    self.dueDate = dueDate
    self.dueDateIsDateOnly = dueDateIsDateOnly
    self.isCompleted = isCompleted
    self.completionDate = completionDate
    self.priority = priority
    self.alarms = alarms
    self.recurrenceRules = recurrenceRules
    self.attendees = attendees
    self.creationDate = creationDate
    self.lastModifiedDate = lastModifiedDate
  }
}

public struct MutationRecord<Value: Codable & Sendable>: Codable, Sendable {
  public let operation: String
  public let changed: Bool
  public let dryRun: Bool
  public let value: Value

  public init(operation: String, changed: Bool, dryRun: Bool, value: Value) {
    self.operation = operation
    self.changed = changed
    self.dryRun = dryRun
    self.value = value
  }
}

public enum FieldChange<Value: Sendable>: Sendable {
  case unchanged
  case set(Value)
  case clear
}
