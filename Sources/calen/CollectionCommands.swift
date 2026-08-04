import ArgumentParser
import CalenCore

struct CalendarsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "calendars",
    abstract: "Manage event calendars.",
    subcommands: [
      CalendarsList.self,
      CalendarsShow.self,
      CalendarsCreate.self,
      CalendarsUpdate.self,
      CalendarsRename.self,
      CalendarsRecolor.self,
      CalendarsDelete.self,
    ],
    defaultSubcommand: CalendarsList.self
  )
}

struct ListsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "lists",
    abstract: "Manage reminder lists.",
    subcommands: [
      ListsList.self,
      ListsShow.self,
      ListsCreate.self,
      ListsUpdate.self,
      ListsRename.self,
      ListsRecolor.self,
      ListsDelete.self,
    ],
    defaultSubcommand: ListsList.self
  )
}

struct CalendarsList: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List event calendars."
  )

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await listCollections(entity: .event, output: output)
  }
}

struct ListsList: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List reminder lists."
  )

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await listCollections(entity: .reminder, output: output)
  }
}

struct CalendarsShow: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "show",
    abstract: "Show a calendar by identifier or exact title."
  )

  @Argument(help: "Calendar identifier or exact title.")
  var calendar: String

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await showCollection(calendar, entity: .event, output: output)
  }
}

struct ListsShow: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "show",
    abstract: "Show a reminder list by identifier or exact title."
  )

  @Argument(help: "Reminder list identifier or exact title.")
  var list: String

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await showCollection(list, entity: .reminder, output: output)
  }
}

struct CalendarsCreate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create",
    abstract: "Create an event calendar.",
    discussion: """
      Example:
        calen calendars create --title "Projects" --color "#4F8EF7"
      """
  )

  @Option(name: .long, help: "Calendar title. Prompted for in an interactive terminal.")
  var title: String?

  @Option(name: .long, help: "Source identifier or exact title. Defaults to the event source.")
  var source: String?

  @Option(name: .long, help: "Calendar color as #RRGGBB or #RRGGBBAA.")
  var color: String?

  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await createCollection(
      entity: .event,
      title: title,
      source: source,
      color: color,
      dryRun: dryRun.dryRun,
      output: output
    )
  }
}

struct ListsCreate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "create",
    abstract: "Create a reminder list.",
    discussion: """
      Example:
        calen lists create --title "Launch" --color "#FF9500"
      """
  )

  @Option(name: .long, help: "List title. Prompted for in an interactive terminal.")
  var title: String?

  @Option(name: .long, help: "Source identifier or exact title. Defaults to the reminder source.")
  var source: String?

  @Option(name: .long, help: "List color as #RRGGBB or #RRGGBBAA.")
  var color: String?

  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await createCollection(
      entity: .reminder,
      title: title,
      source: source,
      color: color,
      dryRun: dryRun.dryRun,
      output: output
    )
  }
}

struct CalendarsUpdate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update a calendar title or color."
  )

  @Argument(help: "Calendar identifier or exact title.")
  var calendar: String

  @Option(name: .long, help: "New title.")
  var title: String?

  @Option(name: .long, help: "New color as #RRGGBB or #RRGGBBAA.")
  var color: String?

  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await updateCollection(
      calendar,
      entity: .event,
      title: title,
      color: color,
      dryRun: dryRun.dryRun,
      output: output
    )
  }
}

struct ListsUpdate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update a reminder list title or color."
  )

  @Argument(help: "Reminder list identifier or exact title.")
  var list: String

  @Option(name: .long, help: "New title.")
  var title: String?

  @Option(name: .long, help: "New color as #RRGGBB or #RRGGBBAA.")
  var color: String?

  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await updateCollection(
      list,
      entity: .reminder,
      title: title,
      color: color,
      dryRun: dryRun.dryRun,
      output: output
    )
  }
}

struct CalendarsRename: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "rename",
    abstract: "Rename an event calendar."
  )

  @Argument(help: "Calendar identifier or exact title.")
  var calendar: String

  @Option(name: .long, help: "New calendar title.")
  var title: String

  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await updateCollection(
      calendar,
      entity: .event,
      title: title,
      color: nil,
      dryRun: dryRun.dryRun,
      output: output
    )
  }
}

struct ListsRename: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "rename",
    abstract: "Rename a reminder list."
  )

  @Argument(help: "Reminder list identifier or exact title.")
  var list: String

  @Option(name: .long, help: "New list title.")
  var title: String

  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await updateCollection(
      list,
      entity: .reminder,
      title: title,
      color: nil,
      dryRun: dryRun.dryRun,
      output: output
    )
  }
}

struct CalendarsRecolor: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "recolor",
    abstract: "Change an event calendar color."
  )

  @Argument(help: "Calendar identifier or exact title.")
  var calendar: String

  @Option(name: .long, help: "New color as #RRGGBB or #RRGGBBAA.")
  var color: String

  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await updateCollection(
      calendar,
      entity: .event,
      title: nil,
      color: color,
      dryRun: dryRun.dryRun,
      output: output
    )
  }
}

struct ListsRecolor: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "recolor",
    abstract: "Change a reminder list color."
  )

  @Argument(help: "Reminder list identifier or exact title.")
  var list: String

  @Option(name: .long, help: "New color as #RRGGBB or #RRGGBBAA.")
  var color: String

  @OptionGroup var dryRun: DryRunOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await updateCollection(
      list,
      entity: .reminder,
      title: nil,
      color: color,
      dryRun: dryRun.dryRun,
      output: output
    )
  }
}

struct CalendarsDelete: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "delete",
    abstract: "Delete an event calendar and every event it contains."
  )

  @Argument(help: "Calendar identifier or exact title.")
  var calendar: String

  @OptionGroup var destructive: DestructiveOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await deleteCollection(
      calendar,
      entity: .event,
      destructive: destructive,
      output: output
    )
  }
}

struct ListsDelete: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "delete",
    abstract: "Delete a reminder list and every reminder it contains."
  )

  @Argument(help: "Reminder list identifier or exact title.")
  var list: String

  @OptionGroup var destructive: DestructiveOptions
  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    try await deleteCollection(
      list,
      entity: .reminder,
      destructive: destructive,
      output: output
    )
  }
}

private func listCollections(entity: EntityKind, output: OutputOptions) async throws {
  let service = await EventKitService.shared
  try Output.collections(try await service.collections(for: entity), json: output.json)
}

private func showCollection(
  _ value: String,
  entity: EntityKind,
  output: OutputOptions
) async throws {
  let service = await EventKitService.shared
  try Output.collection(
    try await service.collection(identifierOrTitle: value, entity: entity),
    json: output.json
  )
}

private func createCollection(
  entity: EntityKind,
  title: String?,
  source: String?,
  color: String?,
  dryRun: Bool,
  output: OutputOptions
) async throws {
  let resolvedTitle = try Terminal.requiredValue(
    title,
    name: "title",
    prompt: entity == .event ? "Calendar title" : "Reminder list title"
  )
  let parsedColor = try color.map(CalendarColor.init(hex:))
  let service = await EventKitService.shared
  let mutation = try await service.createCollection(
    entity: entity,
    title: resolvedTitle,
    source: source,
    color: parsedColor,
    dryRun: dryRun
  )
  try Output.mutation(mutation, json: output.json) {
    "\($0.title) (\($0.identifier ?? "not saved"))"
  }
}

private func updateCollection(
  _ value: String,
  entity: EntityKind,
  title: String?,
  color: String?,
  dryRun: Bool,
  output: OutputOptions
) async throws {
  guard title != nil || color != nil else {
    throw CalenError.invalidInput("Pass --title, --color, or both.")
  }
  let parsedColor = try color.map(CalendarColor.init(hex:))
  let service = await EventKitService.shared
  let mutation = try await service.updateCollection(
    identifierOrTitle: value,
    entity: entity,
    title: title,
    color: parsedColor,
    dryRun: dryRun
  )
  try Output.mutation(mutation, json: output.json) {
    "\($0.title) (\($0.identifier ?? "not saved"))"
  }
}

private func deleteCollection(
  _ value: String,
  entity: EntityKind,
  destructive: DestructiveOptions,
  output: OutputOptions
) async throws {
  try Terminal.confirm(
    entity == .event
      ? "Delete calendar “\(value)” and all of its events?"
      : "Delete reminder list “\(value)” and all of its reminders?",
    force: destructive.force,
    dryRun: destructive.dryRun
  )
  let service = await EventKitService.shared
  let mutation = try await service.deleteCollection(
    identifierOrTitle: value,
    entity: entity,
    dryRun: destructive.dryRun
  )
  try Output.mutation(mutation, json: output.json) {
    "\($0.title) (\($0.identifier ?? "-"))"
  }
}
