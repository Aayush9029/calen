import ArgumentParser
import CalenCore
import Foundation

struct EventsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "events",
    abstract: "Create, inspect, search, update, move, and delete events.",
    subcommands: [
      EventsList.self,
      EventsShow.self,
      EventsCreate.self,
      EventsUpdate.self,
      EventsMove.self,
      EventsDelete.self,
      EventsSearch.self,
    ],
    defaultSubcommand: EventsList.self
  )
}

struct EventRangeOptions: ParsableArguments {
  @Option(name: .long, help: "Range start. Defaults to today.")
  var from: String?

  @Option(name: .long, help: "Range end. Defaults to 30 days after the start.")
  var to: String?

  @Option(name: .long, help: "Calendar identifier or exact title.")
  var calendar: String?

  @Option(name: .long, help: "Maximum number of results.")
  var limit: Int?

  @Option(name: .long, help: "Interpret local dates in this IANA time zone.")
  var timeZone: String?

  func values(searchDefaults: Bool = false) throws -> (Date, Date, DateParser) {
    let zone = try DateParser.timeZone(named: timeZone)
    let parser = DateParser(timeZone: zone)
    let now = Date()
    let start: Date
    let end: Date
    if searchDefaults {
      start =
        try from.map { try parseDateKeyword($0, parser: parser) }
        ?? parser.calendar.date(byAdding: .year, value: -1, to: now)!
      end =
        try to.map { try parseDateKeyword($0, parser: parser) }
        ?? parser.calendar.date(byAdding: .year, value: 3, to: now)!
    } else {
      start =
        try from.map { try parseDateKeyword($0, parser: parser) }
        ?? parser.startOfDay(for: now)
      end =
        try to.map { try parseDateKeyword($0, parser: parser) }
        ?? parser.addingDays(30, to: start)
    }
    return (start, end, parser)
  }
}

struct EventsList: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List event occurrences in a date range.",
    discussion: """
      EventKit returns one row per occurrence for recurring events. The identifier \
      and occurrence date together select a particular occurrence.

      Example:
        calen events list --from 2026-08-01 --to 2026-09-01 --json
      """
  )

  @OptionGroup var range: EventRangeOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let (from, to, _) = try range.values()
    let service = await EventKitService.shared
    try Output.events(
      try await service.events(
        from: from,
        to: to,
        calendar: range.calendar,
        search: nil,
        limit: range.limit
      ),
      json: output.json
    )
  }
}

struct EventsSearch: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "search",
    abstract: "Search event titles, notes, locations, and URLs.",
    discussion: """
      Example:
        calen events search "design review" --from 2026-01-01 --json
      """
  )

  @Argument(help: "Case-insensitive search text.")
  var query: String

  @OptionGroup var range: EventRangeOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let (from, to, _) = try range.values(searchDefaults: true)
    let service = await EventKitService.shared
    try Output.events(
      try await service.events(
        from: from,
        to: to,
        calendar: range.calendar,
        search: query,
        limit: range.limit
      ),
      json: output.json
    )
  }
}

struct EventsShow: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "show",
    abstract: "Show an event or one recurring occurrence."
  )

  @Argument(help: "Event identifier.")
  var identifier: String

  @Option(name: .long, help: "Interpret --occurrence in this IANA time zone.")
  var timeZone: String?

  @OptionGroup var selector: EventSelectorOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let parser = DateParser(timeZone: try DateParser.timeZone(named: timeZone))
    let service = await EventKitService.shared
    try Output.event(
      try await service.event(
        selector.selector(identifier: identifier, parser: parser)
      ),
      json: output.json
    )
  }
}

struct EventsCreate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create",
    abstract: "Create an event from flags or interactive prompts.",
    discussion: """
      Examples:
        calen events create --title "Planning" --start "2026-08-05 09:00" --end "2026-08-05 10:00"
        calen events create --title "Offsite" --start 2026-08-10 --end 2026-08-12 --all-day
        calen events create --title "Standup" --start "2026-08-05 09:00" --repeat weekly --repeat-on mon,wed,fri
        calen events create
      """
  )

  @Option(name: .long, help: "Event title. Prompted for in an interactive terminal.")
  var title: String?

  @Option(name: .long, help: "Start date. Prompted for in an interactive terminal.")
  var start: String?

  @Option(name: .long, help: "End date. Defaults to one hour later or the next all-day date.")
  var end: String?

  @Flag(name: .long, help: "Create an all-day event using YYYY-MM-DD dates.")
  var allDay = false

  @Option(name: .long, help: "Calendar identifier or exact title.")
  var calendar: String?

  @Option(name: .long, help: "Event notes.")
  var notes: String?

  @Option(name: .long, help: "Event URL including its scheme.")
  var url: String?

  @Option(name: .long, help: "Event location or structured location title.")
  var location: String?

  @Option(name: .long, help: "IANA time zone for local input and the event.")
  var timeZone: String?

  @Option(name: .long, help: "Availability: busy, free, tentative, or unavailable.")
  var availability: EventAvailabilityValue?

  @Option(
    name: .long,
    help: "Unsupported by public EventKit. Accepted only to return an actionable error."
  )
  var travelTime: String?

  @OptionGroup var structuredLocation: StructuredLocationOptions
  @OptionGroup var alarms: AlarmOptions
  @OptionGroup var recurrence: RecurrenceOptions
  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try rejectTravelTime(travelTime)
    let zone = try DateParser.timeZone(named: timeZone)
    let parser = DateParser(timeZone: zone)
    let now = Date()
    let defaultStart: String
    if allDay {
      defaultStart = formatLocal(parser.startOfDay(for: now), format: "yyyy-MM-dd", zone: zone)
    } else {
      let nextHour = parser.calendar.nextDate(
        after: now,
        matching: DateComponents(minute: 0, second: 0),
        matchingPolicy: .nextTime
      )!
      defaultStart = formatLocal(nextHour, format: "yyyy-MM-dd HH:mm", zone: zone)
    }
    let resolvedTitle = try Terminal.requiredValue(
      title,
      name: "title",
      prompt: "Event title"
    )
    let resolvedStart = try Terminal.requiredValue(
      start,
      name: "start",
      prompt: "Start",
      defaultValue: defaultStart
    )
    let parsedStart = try parser.parse(resolvedStart)
    let parsedEnd: ParsedDate
    if let end {
      parsedEnd = try parser.parse(end)
    } else if allDay {
      parsedEnd = ParsedDate(
        date: try parser.addingDays(1, to: parsedStart.date),
        isDateOnly: true,
        timeZone: zone
      )
    } else {
      parsedEnd = ParsedDate(
        date: parsedStart.date.addingTimeInterval(3_600),
        isDateOnly: false,
        timeZone: zone
      )
    }

    let input = EventCreateInput(
      title: resolvedTitle,
      calendar: calendar,
      start: parsedStart,
      end: parsedEnd,
      allDay: allDay,
      notes: notes,
      url: try url.map(ValueTools.validateURL),
      location: location,
      structuredLocation: try structuredLocation.spec(title: location),
      timeZone: timeZone == nil ? nil : zone,
      availability: availability,
      alarms: try alarms.specs(parser: parser),
      recurrence: try recurrence.spec(parser: parser)
    )
    let service = await EventKitService.shared
    let mutation = try await service.createEvent(input, dryRun: dryRun.dryRun)
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) (\($0.identifier ?? "not saved"))"
    }
  }
}

struct EventsUpdate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update an event with explicit recurring span behavior.",
    discussion: """
      Recurring events require --span this or --span future.

      Example:
        calen events update EVENT_ID --title "New title" --span future
      """
  )

  @Argument(help: "Event identifier.")
  var identifier: String

  @Option(name: .long, help: "New title.")
  var title: String?

  @Option(name: .long, help: "New start date.")
  var start: String?

  @Option(name: .long, help: "New end date.")
  var end: String?

  @Option(name: .long, help: "Set timed or all-day event behavior.")
  var kind: EventKindOption?

  @Option(name: .long, help: "New notes.")
  var notes: String?

  @Flag(name: .long, help: "Remove notes.")
  var clearNotes = false

  @Option(name: .long, help: "New URL including its scheme.")
  var url: String?

  @Flag(name: .long, help: "Remove the URL.")
  var clearURL = false

  @Option(name: .long, help: "New location or structured location title.")
  var location: String?

  @Flag(name: .long, help: "Remove location and structured location data.")
  var clearLocation = false

  @Option(name: .long, help: "Set and interpret dates in this IANA time zone.")
  var timeZone: String?

  @Flag(name: .long, help: "Clear the event time zone.")
  var clearTimeZone = false

  @Option(name: .long, help: "Availability: busy, free, tentative, or unavailable.")
  var availability: EventAvailabilityValue?

  @Option(name: .long, help: "Recurring scope: this or future.")
  var span: EventSpan?

  @Option(
    name: .long,
    help: "Unsupported by public EventKit. Accepted only to return an actionable error."
  )
  var travelTime: String?

  @Flag(name: .long, help: "Remove every alarm.")
  var clearAlarms = false

  @Flag(name: .long, help: "Remove every recurrence rule.")
  var clearRecurrence = false

  @OptionGroup var selector: EventSelectorOptions
  @OptionGroup var structuredLocation: StructuredLocationOptions
  @OptionGroup var alarms: AlarmOptions
  @OptionGroup var recurrence: RecurrenceOptions
  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try rejectTravelTime(travelTime)
    try rejectConflicts()
    let zone = try DateParser.timeZone(named: timeZone)
    let parser = DateParser(timeZone: zone)
    var input = EventUpdateInput()
    input.title = title
    input.notes = fieldChange(value: notes, clear: clearNotes)
    input.url = try urlFieldChange(value: url, clear: clearURL)
    input.location = fieldChange(value: location, clear: clearLocation)
    if clearLocation {
      input.structuredLocation = .clear
    } else if let spec = try structuredLocation.spec(title: location) {
      input.structuredLocation = .set(spec)
    }
    input.timeZone =
      clearTimeZone
      ? .clear
      : timeZone == nil ? .unchanged : .set(zone)
    input.start = try start.map { try parser.parse($0) }
    input.end = try end.map { try parser.parse($0) }
    input.allDay = kind?.isAllDay
    input.availability = availability
    if clearAlarms {
      input.alarms = .clear
    } else if alarms.hasValues {
      input.alarms = .set(try alarms.specs(parser: parser))
    }
    if clearRecurrence {
      input.recurrence = .clear
    } else if let spec = try recurrence.spec(parser: parser) {
      input.recurrence = .set(spec)
    }

    let service = await EventKitService.shared
    let mutation = try await service.updateEvent(
      selector.selector(identifier: identifier, parser: parser),
      input: input,
      span: span,
      dryRun: dryRun.dryRun
    )
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) (\($0.identifier ?? "-"))"
    }
  }

  private func rejectConflicts() throws {
    if notes != nil, clearNotes {
      throw CalenError.invalidInput("Use either --notes or --clear-notes.")
    }
    if url != nil, clearURL {
      throw CalenError.invalidInput("Use either --url or --clear-url.")
    }
    if location != nil, clearLocation {
      throw CalenError.invalidInput("Use either --location or --clear-location.")
    }
    if timeZone != nil, clearTimeZone {
      throw CalenError.invalidInput("Use either --time-zone or --clear-time-zone.")
    }
    if alarms.hasValues, clearAlarms {
      throw CalenError.invalidInput("Use alarm values or --clear-alarms, not both.")
    }
    if recurrence.frequency != nil, clearRecurrence {
      throw CalenError.invalidInput("Use --repeat or --clear-recurrence, not both.")
    }
  }
}

struct EventsMove: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "move",
    abstract: "Move an event to another calendar.",
    discussion: "Recurring events require --span this or --span future."
  )

  @Argument(help: "Event identifier.")
  var identifier: String

  @Option(name: .long, help: "Destination calendar identifier or exact title.")
  var calendar: String

  @Option(name: .long, help: "Recurring scope: this or future.")
  var span: EventSpan?

  @Option(name: .long, help: "Interpret --occurrence in this IANA time zone.")
  var timeZone: String?

  @OptionGroup var selector: EventSelectorOptions
  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let parser = DateParser(timeZone: try DateParser.timeZone(named: timeZone))
    let service = await EventKitService.shared
    let mutation = try await service.moveEvent(
      selector.selector(identifier: identifier, parser: parser),
      calendar: calendar,
      span: span,
      dryRun: dryRun.dryRun
    )
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) to \($0.calendarTitle ?? "unknown") (\($0.identifier ?? "-"))"
    }
  }
}

struct EventsDelete: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "delete",
    abstract: "Delete an event or a recurring event span.",
    discussion: "Recurring events require --span this or --span future."
  )

  @Argument(help: "Event identifier.")
  var identifier: String

  @Option(name: .long, help: "Recurring scope: this or future.")
  var span: EventSpan?

  @Option(name: .long, help: "Interpret --occurrence in this IANA time zone.")
  var timeZone: String?

  @OptionGroup var selector: EventSelectorOptions
  @OptionGroup var destructive: DestructiveOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try Terminal.confirm(
      "Delete event “\(identifier)”?",
      force: destructive.force,
      dryRun: destructive.dryRun
    )
    let parser = DateParser(timeZone: try DateParser.timeZone(named: timeZone))
    let service = await EventKitService.shared
    let mutation = try await service.deleteEvent(
      selector.selector(identifier: identifier, parser: parser),
      span: span,
      dryRun: destructive.dryRun
    )
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) (\($0.identifier ?? "-"))"
    }
  }
}

func parseDateKeyword(_ value: String, parser: DateParser) throws -> Date {
  switch value.lowercased() {
  case "today":
    return parser.startOfDay(for: Date())
  case "tomorrow":
    return try parser.addingDays(1, to: parser.startOfDay(for: Date()))
  case "now":
    return Date()
  default:
    return try parser.parse(value).date
  }
}

private func formatLocal(_ date: Date, format: String, zone: TimeZone) -> String {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = zone
  formatter.dateFormat = format
  return formatter.string(from: date)
}

private func rejectTravelTime(_ value: String?) throws {
  guard value == nil else {
    throw CalenError.platformLimitation(
      "Travel time is not exposed by the public EventKit EKEvent API on macOS, so third-party tools cannot read or write it."
    )
  }
}

func fieldChange<Value: Sendable>(
  value: Value?,
  clear: Bool
) -> FieldChange<Value> {
  if clear {
    return .clear
  }
  if let value {
    return .set(value)
  }
  return .unchanged
}

func urlFieldChange(value: String?, clear: Bool) throws -> FieldChange<URL> {
  if clear {
    return .clear
  }
  if let value {
    return .set(try ValueTools.validateURL(value))
  }
  return .unchanged
}
