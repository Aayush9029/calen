import ArgumentParser
import CalenCore
import Foundation

extension EntityKind: ExpressibleByArgument {}
extension EventSpan: ExpressibleByArgument {}
extension EventAvailabilityValue: ExpressibleByArgument {}
extension RecurrenceFrequency: ExpressibleByArgument {}

struct OutputOptions: ParsableArguments {
  @Flag(name: .long, help: "Emit stable machine-readable JSON.")
  var json = false
}

struct DestructiveOptions: ParsableArguments {
  @Flag(name: .long, help: "Skip the interactive confirmation.")
  var force = false

  @Flag(name: .long, help: "Show the operation without changing EventKit.")
  var dryRun = false
}

struct DryRunOptions: ParsableArguments {
  @Flag(name: .long, help: "Show the operation without changing EventKit.")
  var dryRun = false
}

struct EventSelectorOptions: ParsableArguments {
  @Flag(name: .long, help: "Treat the identifier as a server-provided external identifier.")
  var externalID = false

  @Option(
    name: .long,
    help: "Select one recurring occurrence by its original ISO 8601 occurrence date."
  )
  var occurrence: String?

  func selector(identifier: String, parser: DateParser) throws -> EventSelector {
    EventSelector(
      identifier: identifier,
      externalIdentifier: externalID,
      occurrenceDate: try occurrence.map { try parser.parse($0).date }
    )
  }
}

struct ReminderSelectorOptions: ParsableArguments {
  @Flag(name: .long, help: "Treat the identifier as a server-provided external identifier.")
  var externalID = false

  func selector(identifier: String) -> ReminderSelector {
    ReminderSelector(identifier: identifier, externalIdentifier: externalID)
  }
}

struct AlarmOptions: ParsableArguments {
  @Option(
    name: .long,
    help: "Add a relative alarm such as -15m or 1h. Repeat for multiple alarms."
  )
  var alarmRelative: [String] = []

  @Option(
    name: .long,
    help: "Add an alarm at an ISO 8601 or local date. Repeat for multiple alarms."
  )
  var alarmAt: [String] = []

  @Option(
    name: .long,
    help: "Add a geofence alarm as enter|leave,latitude,longitude,radius,title."
  )
  var alarmLocation: [String] = []

  func specs(parser: DateParser) throws -> [AlarmSpec] {
    let relative = try alarmRelative.map {
      AlarmSpec.relative(try DurationParser.parse($0))
    }
    let absolute = try alarmAt.map {
      AlarmSpec.absolute(try parser.parse($0).date)
    }
    let locations = try alarmLocation.map(AlarmParser.location)
    return relative + absolute + locations
  }

  var hasValues: Bool {
    !alarmRelative.isEmpty || !alarmAt.isEmpty || !alarmLocation.isEmpty
  }
}

struct RecurrenceOptions: ParsableArguments {
  @Option(name: .customLong("repeat"), help: "Repeat daily, weekly, monthly, or yearly.")
  var frequency: RecurrenceFrequency?

  @Option(name: .long, help: "Recurrence interval. Defaults to 1.")
  var interval = 1

  @Option(
    name: .long,
    help: "Comma-separated weekdays such as mon,wed,fri or 2tue,-1fri."
  )
  var repeatOn: String?

  @Option(name: .long, help: "Comma-separated month days from -31 through 31.")
  var monthDays: String?

  @Option(name: .long, help: "Comma-separated months from 1 through 12.")
  var months: String?

  @Option(name: .long, help: "Comma-separated weeks of year from -53 through 53.")
  var yearWeeks: String?

  @Option(name: .long, help: "Comma-separated days of year from -366 through 366.")
  var yearDays: String?

  @Option(name: .long, help: "Comma-separated recurrence set positions.")
  var setPositions: String?

  @Option(name: .long, help: "Stop the recurrence at this date.")
  var repeatUntil: String?

  @Option(name: .long, help: "Stop after this many occurrences.")
  var repeatCount: Int?

  func spec(parser: DateParser) throws -> RecurrenceSpec? {
    guard let frequency else {
      let hasDependentValue =
        interval != 1 || repeatOn != nil || monthDays != nil
        || months != nil || yearWeeks != nil || yearDays != nil
        || setPositions != nil || repeatUntil != nil || repeatCount != nil
      if hasDependentValue {
        throw CalenError.invalidInput("Recurrence options require --repeat.")
      }
      return nil
    }
    if repeatUntil != nil, repeatCount != nil {
      throw CalenError.invalidInput("Use either --repeat-until or --repeat-count, not both.")
    }
    let end: RecurrenceEndSpec?
    if let repeatUntil {
      end = .date(try parser.parse(repeatUntil).date)
    } else if let repeatCount {
      end = .count(repeatCount)
    } else {
      end = nil
    }
    return try RecurrenceSpec(
      frequency: frequency,
      interval: interval,
      daysOfWeek: RecurrenceParser.weekdays(repeatOn),
      daysOfMonth: RecurrenceParser.integers(monthDays, name: "month day"),
      monthsOfYear: RecurrenceParser.integers(months, name: "month"),
      weeksOfYear: RecurrenceParser.integers(yearWeeks, name: "week of year"),
      daysOfYear: RecurrenceParser.integers(yearDays, name: "day of year"),
      setPositions: RecurrenceParser.integers(setPositions, name: "set position"),
      end: end
    )
  }
}

struct StructuredLocationOptions: ParsableArguments {
  @Option(name: .long, help: "Structured location latitude.")
  var latitude: Double?

  @Option(name: .long, help: "Structured location longitude.")
  var longitude: Double?

  @Option(name: .long, help: "Structured location radius in meters. Defaults to 0.")
  var locationRadius = 0.0

  func spec(title: String?) throws -> StructuredLocationSpec? {
    guard latitude != nil || longitude != nil else {
      return nil
    }
    guard let latitude, let longitude else {
      throw CalenError.invalidInput("--latitude and --longitude must be used together.")
    }
    guard let title, !title.isEmpty else {
      throw CalenError.invalidInput(
        "A structured location requires --location as its title."
      )
    }
    return try StructuredLocationSpec(
      title: title,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: locationRadius
    )
  }
}

enum PermissionSelection: String, ExpressibleByArgument, CaseIterable {
  case all
  case events
  case reminders

  var entities: Set<EntityKind> {
    switch self {
    case .all: [.event, .reminder]
    case .events: [.event]
    case .reminders: [.reminder]
    }
  }
}

enum CompletionFilter: String, ExpressibleByArgument, CaseIterable {
  case all
  case completed
  case incomplete

  var value: Bool? {
    switch self {
    case .all: nil
    case .completed: true
    case .incomplete: false
    }
  }
}

enum EventKindOption: String, ExpressibleByArgument, CaseIterable {
  case timed
  case allDay = "all-day"

  var isAllDay: Bool {
    self == .allDay
  }
}
