@preconcurrency import EventKit
import Foundation

@MainActor
public final class EventKitService {
  public static let shared = EventKitService()

  let eventStore: EKEventStore

  public init(eventStore: EKEventStore = EKEventStore()) {
    self.eventStore = eventStore
  }

  public func authorization() -> AuthorizationRecord {
    AuthorizationRecord(
      events: accessStatus(for: .event),
      reminders: accessStatus(for: .reminder)
    )
  }

  public func requestAccess(to entities: Set<EntityKind>) async throws -> AuthorizationRecord {
    if entities.contains(.event) {
      let status = accessStatus(for: .event)
      switch status {
      case .denied:
        throw CalenError.authorizationDenied("Calendars")
      case .restricted:
        throw CalenError.authorizationRestricted("Calendars")
      case .notDetermined, .writeOnly:
        _ = try await eventStore.requestFullAccessToEvents()
        eventStore.reset()
      case .fullAccess, .unknown:
        break
      }
    }

    if entities.contains(.reminder) {
      let status = accessStatus(for: .reminder)
      switch status {
      case .denied:
        throw CalenError.authorizationDenied("Reminders")
      case .restricted:
        throw CalenError.authorizationRestricted("Reminders")
      case .notDetermined, .writeOnly:
        _ = try await eventStore.requestFullAccessToReminders()
        eventStore.reset()
      case .fullAccess, .unknown:
        break
      }
    }
    return authorization()
  }

  public func diagnostics() -> DiagnosticRecord {
    let bundle = Bundle.main
    return DiagnosticRecord(
      authorization: authorization(),
      bundleIdentifier: bundle.bundleIdentifier,
      binaryPath: CommandLine.arguments.first ?? "",
      calendarUsageDescriptionEmbedded: bundle.object(
        forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription"
      ) != nil,
      remindersUsageDescriptionEmbedded: bundle.object(
        forInfoDictionaryKey: "NSRemindersFullAccessUsageDescription"
      ) != nil,
      macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
      eventStoreIdentifier: eventStore.eventStoreIdentifier,
      travelTimeAPI: "unavailable in public EventKit"
    )
  }

  public func sources() throws -> [SourceRecord] {
    try requireFullAccess(to: [.event, .reminder])
    return eventStore.sources
      .map(sourceRecord)
      .sorted {
        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
  }

  public func source(identifierOrTitle value: String) throws -> SourceRecord {
    try requireFullAccess(to: [.event, .reminder])
    return sourceRecord(try resolveSource(value))
  }

  func requireFullAccess(to entities: Set<EntityKind>) throws {
    for entity in entities {
      let status = accessStatus(for: entity == .event ? .event : .reminder)
      switch status {
      case .fullAccess:
        continue
      case .denied:
        throw CalenError.authorizationDenied(entity.displayName)
      case .restricted:
        throw CalenError.authorizationRestricted(entity.displayName)
      case .notDetermined:
        throw CalenError.invalidInput(
          "\(entity.displayName) access has not been requested. Run `calen permissions request`."
        )
      case .writeOnly:
        throw CalenError.invalidInput(
          "\(entity.displayName) access is write-only. Run `calen permissions request` for full access."
        )
      case .unknown:
        throw CalenError.invalidInput(
          "\(entity.displayName) access is in an unknown state."
        )
      }
    }
  }

  func accessStatus(for entity: EKEntityType) -> AccessStatus {
    switch EKEventStore.authorizationStatus(for: entity) {
    case .notDetermined: .notDetermined
    case .restricted: .restricted
    case .denied: .denied
    case .writeOnly: .writeOnly
    case .fullAccess: .fullAccess
    @unknown default: .unknown
    }
  }

  func resolveSource(_ value: String) throws -> EKSource {
    if let source = eventStore.source(withIdentifier: value) {
      return source
    }
    let matches = eventStore.sources.filter {
      $0.title.compare(value, options: .caseInsensitive) == .orderedSame
    }
    guard !matches.isEmpty else {
      throw CalenError.notFound("No calendar source matches “\(value)”.")
    }
    guard matches.count == 1 else {
      throw CalenError.ambiguous(
        value,
        matches: matches.map { "\($0.title) (\($0.sourceIdentifier))" }
      )
    }
    return matches[0]
  }

  func defaultSource(for entity: EKEntityType) throws -> EKSource {
    if entity == .event, let source = eventStore.defaultCalendarForNewEvents?.source {
      return source
    }
    if entity == .reminder, let source = eventStore.defaultCalendarForNewReminders()?.source {
      return source
    }
    if let local = eventStore.sources.first(where: { $0.sourceType == .local }) {
      return local
    }
    guard let source = eventStore.sources.first else {
      throw CalenError.notFound("No Calendar account is available for a new collection.")
    }
    return source
  }
}
