import ArgumentParser
import CalenCore
import Foundation

struct RemindersCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reminders",
    abstract: "Create, inspect, search, update, move, complete, and delete reminders.",
    subcommands: [
      RemindersList.self,
      RemindersShow.self,
      RemindersCreate.self,
      RemindersUpdate.self,
      RemindersMove.self,
      RemindersComplete.self,
      RemindersReopen.self,
      RemindersDelete.self,
      RemindersSearch.self,
    ],
    defaultSubcommand: RemindersList.self
  )
}

struct ReminderFilterOptions: ParsableArguments {
  @Option(name: .long, help: "Reminder list identifier or exact title.")
  var list: String?

  @Option(name: .long, help: "Filter by all, completed, or incomplete. Defaults to all.")
  var state: CompletionFilter = .all

  @Option(name: .long, help: "Include reminders due on or after this date.")
  var dueAfter: String?

  @Option(name: .long, help: "Include reminders due on or before this date.")
  var dueBefore: String?

  @Option(name: .long, help: "Maximum number of results.")
  var limit: Int?

  @Option(name: .long, help: "Interpret local dates in this IANA time zone.")
  var timeZone: String?

  func parsedDates() throws -> (Date?, Date?) {
    let parser = DateParser(timeZone: try DateParser.timeZone(named: timeZone))
    return (
      try dueAfter.map { try parseDateKeyword($0, parser: parser) },
      try dueBefore.map { try parseDateKeyword($0, parser: parser) }
    )
  }
}

struct RemindersList: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List reminders.",
    discussion: """
      Example:
        calen reminders list --state incomplete --due-before 2026-09-01 --json
      """
  )

  @OptionGroup var filters: ReminderFilterOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await runReminderList(query: nil, filters: filters, output: output)
  }
}

struct RemindersSearch: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "search",
    abstract: "Search reminder titles, notes, locations, and URLs."
  )

  @Argument(help: "Case-insensitive search text.")
  var query: String

  @OptionGroup var filters: ReminderFilterOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await runReminderList(query: query, filters: filters, output: output)
  }
}

struct RemindersShow: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "show",
    abstract: "Show a reminder by identifier."
  )

  @Argument(help: "Reminder identifier.")
  var identifier: String

  @OptionGroup var selector: ReminderSelectorOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let service = await EventKitService.shared
    try Output.reminder(
      try await service.reminder(selector.selector(identifier: identifier)),
      json: output.json
    )
  }
}

struct RemindersCreate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create",
    abstract: "Create a reminder from flags or an interactive title prompt.",
    discussion: """
      Examples:
        calen reminders create --title "Send report" --due "2026-08-05 17:00"
        calen reminders create --title "Water plants" --due 2026-08-06 --repeat weekly
        calen reminders create
      """
  )

  @Option(name: .long, help: "Reminder title. Prompted for in an interactive terminal.")
  var title: String?

  @Option(name: .long, help: "Reminder list identifier or exact title.")
  var list: String?

  @Option(name: .long, help: "Start date.")
  var start: String?

  @Option(name: .long, help: "Due date.")
  var due: String?

  @Option(name: .long, help: "Interpret dates in this IANA time zone.")
  var timeZone: String?

  @Option(name: .long, help: "Priority from 0 through 9. Defaults to 0.")
  var priority = 0

  @Option(name: .long, help: "Reminder notes.")
  var notes: String?

  @Option(name: .long, help: "Reminder URL including its scheme.")
  var url: String?

  @Option(name: .long, help: "Reminder location label.")
  var location: String?

  @OptionGroup var alarms: AlarmOptions
  @OptionGroup var recurrence: RecurrenceOptions
  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let parser = DateParser(timeZone: try DateParser.timeZone(named: timeZone))
    let resolvedTitle = try Terminal.requiredValue(
      title,
      name: "title",
      prompt: "Reminder title"
    )
    let input = ReminderCreateInput(
      title: resolvedTitle,
      list: list,
      notes: notes,
      url: try url.map(ValueTools.validateURL),
      location: location,
      start: try start.map { try parser.parse($0) },
      due: try due.map { try parser.parse($0) },
      priority: priority,
      alarms: try alarms.specs(parser: parser),
      recurrence: try recurrence.spec(parser: parser)
    )
    let service = await EventKitService.shared
    let mutation = try await service.createReminder(input, dryRun: dryRun.dryRun)
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) (\($0.identifier ?? "not saved"))"
    }
  }
}

struct RemindersUpdate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update reminder fields, alarms, or recurrence."
  )

  @Argument(help: "Reminder identifier.")
  var identifier: String

  @Option(name: .long, help: "New title.")
  var title: String?

  @Option(name: .long, help: "New notes.")
  var notes: String?

  @Flag(name: .long, help: "Remove notes.")
  var clearNotes = false

  @Option(name: .long, help: "New URL including its scheme.")
  var url: String?

  @Flag(name: .long, help: "Remove the URL.")
  var clearURL = false

  @Option(name: .long, help: "New location label.")
  var location: String?

  @Flag(name: .long, help: "Remove the location label.")
  var clearLocation = false

  @Option(name: .long, help: "New start date.")
  var start: String?

  @Flag(name: .long, help: "Remove the start date.")
  var clearStart = false

  @Option(name: .long, help: "New due date.")
  var due: String?

  @Flag(name: .long, help: "Remove the due date.")
  var clearDue = false

  @Option(name: .long, help: "Interpret local dates in this IANA time zone.")
  var timeZone: String?

  @Option(name: .long, help: "Priority from 0 through 9.")
  var priority: Int?

  @Flag(name: .long, help: "Remove every alarm.")
  var clearAlarms = false

  @Flag(name: .long, help: "Remove every recurrence rule.")
  var clearRecurrence = false

  @OptionGroup var selector: ReminderSelectorOptions
  @OptionGroup var alarms: AlarmOptions
  @OptionGroup var recurrence: RecurrenceOptions
  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try rejectConflicts()
    let parser = DateParser(timeZone: try DateParser.timeZone(named: timeZone))
    var input = ReminderUpdateInput()
    input.title = title
    input.notes = fieldChange(value: notes, clear: clearNotes)
    input.url = try urlFieldChange(value: url, clear: clearURL)
    input.location = fieldChange(value: location, clear: clearLocation)
    input.start = try dateFieldChange(value: start, clear: clearStart, parser: parser)
    input.due = try dateFieldChange(value: due, clear: clearDue, parser: parser)
    input.priority = priority
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
    let mutation = try await service.updateReminder(
      selector.selector(identifier: identifier),
      input: input,
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
    if start != nil, clearStart {
      throw CalenError.invalidInput("Use either --start or --clear-start.")
    }
    if due != nil, clearDue {
      throw CalenError.invalidInput("Use either --due or --clear-due.")
    }
    if alarms.hasValues, clearAlarms {
      throw CalenError.invalidInput("Use alarm values or --clear-alarms, not both.")
    }
    if recurrence.frequency != nil, clearRecurrence {
      throw CalenError.invalidInput("Use --repeat or --clear-recurrence, not both.")
    }
  }
}

struct RemindersMove: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "move",
    abstract: "Move a reminder to another list."
  )

  @Argument(help: "Reminder identifier.")
  var identifier: String

  @Option(name: .long, help: "Destination reminder list identifier or exact title.")
  var list: String

  @OptionGroup var selector: ReminderSelectorOptions
  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let service = await EventKitService.shared
    let mutation = try await service.moveReminder(
      selector.selector(identifier: identifier),
      list: list,
      dryRun: dryRun.dryRun
    )
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) to \($0.listTitle ?? "unknown") (\($0.identifier ?? "-"))"
    }
  }
}

struct RemindersComplete: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "complete",
    abstract: "Mark a reminder complete."
  )

  @Argument(help: "Reminder identifier.")
  var identifier: String

  @Option(name: .long, help: "Completion date. Defaults to now.")
  var at: String?

  @Option(name: .long, help: "Interpret a local completion date in this IANA time zone.")
  var timeZone: String?

  @OptionGroup var selector: ReminderSelectorOptions
  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let parser = DateParser(timeZone: try DateParser.timeZone(named: timeZone))
    let service = await EventKitService.shared
    let mutation = try await service.setReminderCompletion(
      selector.selector(identifier: identifier),
      completed: true,
      completionDate: try at.map { try parser.parse($0).date },
      dryRun: dryRun.dryRun
    )
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) (\($0.identifier ?? "-"))"
    }
  }
}

struct RemindersReopen: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reopen",
    abstract: "Mark a completed reminder incomplete."
  )

  @Argument(help: "Reminder identifier.")
  var identifier: String

  @OptionGroup var selector: ReminderSelectorOptions
  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let service = await EventKitService.shared
    let mutation = try await service.setReminderCompletion(
      selector.selector(identifier: identifier),
      completed: false,
      completionDate: nil,
      dryRun: dryRun.dryRun
    )
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) (\($0.identifier ?? "-"))"
    }
  }
}

struct RemindersDelete: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "delete",
    abstract: "Delete a reminder."
  )

  @Argument(help: "Reminder identifier.")
  var identifier: String

  @OptionGroup var selector: ReminderSelectorOptions
  @OptionGroup var destructive: DestructiveOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try Terminal.confirm(
      "Delete reminder “\(identifier)”?",
      force: destructive.force,
      dryRun: destructive.dryRun
    )
    let service = await EventKitService.shared
    let mutation = try await service.deleteReminder(
      selector.selector(identifier: identifier),
      dryRun: destructive.dryRun
    )
    try Output.mutation(mutation, json: output.json) {
      "\($0.title) (\($0.identifier ?? "-"))"
    }
  }
}

private func runReminderList(
  query: String?,
  filters: ReminderFilterOptions,
  output: OutputOptions
) async throws {
  let (dueAfter, dueBefore) = try filters.parsedDates()
  let service = await EventKitService.shared
  try Output.reminders(
    try await service.reminders(
      list: filters.list,
      search: query,
      completed: filters.state.value,
      dueAfter: dueAfter,
      dueBefore: dueBefore,
      limit: filters.limit
    ),
    json: output.json
  )
}

private func dateFieldChange(
  value: String?,
  clear: Bool,
  parser: DateParser
) throws -> FieldChange<ParsedDate> {
  if clear {
    return .clear
  }
  if let value {
    return .set(try parser.parse(value))
  }
  return .unchanged
}
