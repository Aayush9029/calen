@preconcurrency import EventKit
import Foundation

@MainActor
extension EventKitService {
  public func collections(for entity: EntityKind) throws -> [CollectionRecord] {
    try requireFullAccess(to: [entity])
    let eventKitEntity: EKEntityType = entity == .event ? .event : .reminder
    return eventStore.calendars(for: eventKitEntity)
      .map { collectionRecord($0, entity: entity) }
      .sorted {
        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
  }

  public func collection(
    identifierOrTitle value: String,
    entity: EntityKind
  ) throws -> CollectionRecord {
    try requireFullAccess(to: [entity])
    return collectionRecord(try resolveCalendar(value, entity: entity), entity: entity)
  }

  public func createCollection(
    entity: EntityKind,
    title: String,
    source: String?,
    color: CalendarColor?,
    dryRun: Bool
  ) throws -> MutationRecord<CollectionRecord> {
    try requireFullAccess(to: [entity])
    let cleanTitle = try ValueTools.requireNonempty(title, name: collectionName(entity))
    let eventKitEntity: EKEntityType = entity == .event ? .event : .reminder
    let calendar = EKCalendar(for: eventKitEntity, eventStore: eventStore)
    calendar.title = cleanTitle
    calendar.source = try source.map(resolveSource) ?? defaultSource(for: eventKitEntity)
    if let color {
      calendar.cgColor = color.cgColor
    }

    if !dryRun {
      try eventStore.saveCalendar(calendar, commit: true)
    }
    return MutationRecord(
      operation: "create",
      changed: true,
      dryRun: dryRun,
      value: collectionRecord(calendar, entity: entity)
    )
  }

  public func updateCollection(
    identifierOrTitle value: String,
    entity: EntityKind,
    title: String?,
    color: CalendarColor?,
    dryRun: Bool
  ) throws -> MutationRecord<CollectionRecord> {
    try requireFullAccess(to: [entity])
    let calendar = try resolveCalendar(value, entity: entity)
    guard !calendar.isImmutable else {
      throw CalenError.readOnly(
        "\(collectionName(entity)) “\(calendar.title)” is immutable."
      )
    }

    var changed = false
    if let title {
      let cleanTitle = try ValueTools.requireNonempty(title, name: collectionName(entity))
      if calendar.title != cleanTitle {
        calendar.title = cleanTitle
        changed = true
      }
    }
    if let color {
      let existing = CalendarColor(cgColor: calendar.cgColor)
      if existing?.approximatelyEquals(color) != true {
        calendar.cgColor = color.cgColor
        changed = true
      }
    }

    if changed, !dryRun {
      try eventStore.saveCalendar(calendar, commit: true)
    }
    let record = collectionRecord(calendar, entity: entity)
    if dryRun {
      calendar.rollback()
    }
    return MutationRecord(
      operation: "update",
      changed: changed,
      dryRun: dryRun,
      value: record
    )
  }

  public func deleteCollection(
    identifierOrTitle value: String,
    entity: EntityKind,
    dryRun: Bool
  ) throws -> MutationRecord<CollectionRecord> {
    try requireFullAccess(to: [entity])
    let calendar = try resolveCalendar(value, entity: entity)
    guard !calendar.isImmutable else {
      throw CalenError.readOnly(
        "\(collectionName(entity)) “\(calendar.title)” is immutable and cannot be deleted."
      )
    }
    let record = collectionRecord(calendar, entity: entity)
    if !dryRun {
      try eventStore.removeCalendar(calendar, commit: true)
    }
    return MutationRecord(
      operation: "delete",
      changed: true,
      dryRun: dryRun,
      value: record
    )
  }

  func resolveCalendar(_ value: String, entity: EntityKind) throws -> EKCalendar {
    let eventKitEntity: EKEntityType = entity == .event ? .event : .reminder
    if let calendar = eventStore.calendar(withIdentifier: value),
      calendar.allowedEntityTypes.contains(
        entity == .event ? EKEntityMask.event : EKEntityMask.reminder
      )
    {
      return calendar
    }

    let matches = eventStore.calendars(for: eventKitEntity).filter {
      $0.title.compare(value, options: .caseInsensitive) == .orderedSame
    }
    guard !matches.isEmpty else {
      throw CalenError.notFound("No \(collectionName(entity).lowercased()) matches “\(value)”.")
    }
    guard matches.count == 1 else {
      throw CalenError.ambiguous(
        value,
        matches: matches.map { "\($0.title) (\($0.calendarIdentifier))" }
      )
    }
    return matches[0]
  }

  func collectionName(_ entity: EntityKind) -> String {
    entity == .event ? "Calendar" : "Reminder list"
  }
}
