import ArgumentParser
import CalenCore

@main
struct Calen: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "calen",
    abstract: "Manage Apple Calendar and Reminders from the command line.",
    discussion: """
      calen uses EventKit, works with every account configured in Apple Calendar \
      and Reminders, and supports readable or JSON output.

      Examples:
        calen permissions request
        calen events list --from today --to 2026-09-01
        calen events create --title "Focus" --start "2026-08-05 09:00" --end "2026-08-05 10:00"
        calen reminders create --title "Send report" --due "2026-08-05 17:00"
      """,
    version: "0.1.0",
    subcommands: [
      PermissionsCommand.self,
      SourcesCommand.self,
      CalendarsCommand.self,
      ListsCommand.self,
      EventsCommand.self,
      RemindersCommand.self,
    ]
  )
}
