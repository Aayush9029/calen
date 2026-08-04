import ArgumentParser
import CalenCore

struct PermissionsCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "permissions",
    abstract: "Inspect and request Calendar and Reminders access.",
    subcommands: [
      PermissionsStatus.self,
      PermissionsRequest.self,
      PermissionsDiagnose.self,
    ],
    defaultSubcommand: PermissionsStatus.self
  )
}

struct PermissionsStatus: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Show the current EventKit authorization state."
  )

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let service = await EventKitService.shared
    try Output.authorization(await service.authorization(), json: output.json)
  }
}

struct PermissionsRequest: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "request",
    abstract: "Request full Calendar and Reminders access.",
    discussion: """
      The system may show separate permission prompts. If access was previously denied, \
      enable calen for your terminal in System Settings > Privacy & Security.
      """
  )

  @Option(name: .long, help: "Request all, events, or reminders. Defaults to all.")
  var entity: PermissionSelection = .all

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let service = await EventKitService.shared
    let record = try await service.requestAccess(to: entity.entities)
    try Output.authorization(record, json: output.json)
  }
}

struct PermissionsDiagnose: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "diagnose",
    abstract: "Check permissions, embedded usage descriptions, and runtime identity."
  )

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let service = await EventKitService.shared
    try Output.diagnostics(await service.diagnostics(), json: output.json)
  }
}
