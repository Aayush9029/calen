import ArgumentParser
import CalenCore

struct SourcesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sources",
    abstract: "Inspect Calendar account sources.",
    discussion:
      "Sources are read-only in EventKit. A new calendar can choose a source only at creation.",
    subcommands: [SourcesList.self, SourcesShow.self],
    defaultSubcommand: SourcesList.self
  )
}

struct SourcesList: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List Calendar account sources."
  )

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let service = await EventKitService.shared
    try Output.sources(try await service.sources(), json: output.json)
  }
}

struct SourcesShow: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "show",
    abstract: "Show a source by identifier or exact title."
  )

  @Argument(help: "Source identifier or exact title.")
  var source: String

  @OptionGroup var output: OutputOptions

  mutating func run() async throws {
    let service = await EventKitService.shared
    try Output.source(
      try await service.source(identifierOrTitle: source),
      json: output.json
    )
  }
}
