import CoreLocation
@preconcurrency import EventKit
import Foundation

@MainActor
extension EventKitService {
  func sourceRecord(_ source: EKSource) -> SourceRecord {
    SourceRecord(
      identifier: source.sourceIdentifier,
      title: source.title,
      type: sourceTypeName(source.sourceType),
      isDelegate: source.isDelegate,
      eventCalendarCount: source.calendars(for: .event).count,
      reminderListCount: source.calendars(for: .reminder).count
    )
  }

  func collectionRecord(_ calendar: EKCalendar, entity: EntityKind) -> CollectionRecord {
    let defaultIdentifier: String?
    switch entity {
    case .event:
      defaultIdentifier = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
    case .reminder:
      defaultIdentifier = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
    }
    var allowed: [String] = []
    if calendar.allowedEntityTypes.contains(.event) {
      allowed.append("event")
    }
    if calendar.allowedEntityTypes.contains(.reminder) {
      allowed.append("reminder")
    }

    var availabilities: [String] = []
    let supported = calendar.supportedEventAvailabilities
    if supported.contains(.busy) { availabilities.append("busy") }
    if supported.contains(.free) { availabilities.append("free") }
    if supported.contains(.tentative) { availabilities.append("tentative") }
    if supported.contains(.unavailable) { availabilities.append("unavailable") }

    return CollectionRecord(
      identifier: calendar.calendarIdentifier,
      entity: entity,
      title: calendar.title,
      color: CalendarColor(cgColor: calendar.cgColor)?.hex,
      type: calendarTypeName(calendar.type),
      sourceIdentifier: calendar.source?.sourceIdentifier,
      sourceTitle: calendar.source?.title,
      sourceType: calendar.source.map { sourceTypeName($0.sourceType) },
      allowsContentModifications: calendar.allowsContentModifications,
      isImmutable: calendar.isImmutable,
      isSubscribed: calendar.isSubscribed,
      isDefault: calendar.calendarIdentifier == defaultIdentifier,
      allowedEntityTypes: allowed,
      supportedAvailabilities: availabilities
    )
  }

  func eventRecord(_ event: EKEvent) -> EventRecord {
    EventRecord(
      identifier: event.eventIdentifier,
      calendarItemIdentifier: event.calendarItemIdentifier,
      externalIdentifier: event.calendarItemExternalIdentifier,
      title: event.title ?? "",
      notes: event.notes,
      url: event.url?.absoluteString,
      location: event.location,
      structuredLocation: structuredLocationRecord(event.structuredLocation),
      timeZone: event.timeZone?.identifier,
      isAllDay: event.isAllDay,
      startDate: event.startDate,
      endDate: normalizedEndDate(event),
      availability: availabilityName(event.availability),
      status: eventStatusName(event.status),
      calendarIdentifier: event.calendar?.calendarIdentifier,
      calendarTitle: event.calendar?.title,
      occurrenceDate: event.hasRecurrenceRules || event.isDetached
        ? event.occurrenceDate
        : nil,
      isDetached: event.isDetached,
      hasRecurrenceRules: event.hasRecurrenceRules,
      alarms: (event.alarms ?? []).map(alarmRecord),
      recurrenceRules: (event.recurrenceRules ?? []).map(recurrenceRecord),
      organizer: event.organizer.map(participantRecord),
      attendees: (event.attendees ?? []).map(participantRecord),
      creationDate: event.creationDate,
      lastModifiedDate: event.lastModifiedDate,
      travelTimeSeconds: nil,
      travelTimeWritable: false
    )
  }

  func reminderRecord(_ reminder: EKReminder) -> ReminderRecord {
    ReminderRecord(
      identifier: reminder.calendarItemIdentifier,
      externalIdentifier: reminder.calendarItemExternalIdentifier,
      title: reminder.title ?? "",
      notes: reminder.notes,
      url: reminder.url?.absoluteString,
      location: reminder.location,
      timeZone: reminder.timeZone?.identifier,
      listIdentifier: reminder.calendar?.calendarIdentifier,
      listTitle: reminder.calendar?.title,
      startDate: DateComponentsConverter.date(from: reminder.startDateComponents),
      startDateIsDateOnly: DateComponentsConverter.isDateOnly(reminder.startDateComponents),
      dueDate: DateComponentsConverter.date(from: reminder.dueDateComponents),
      dueDateIsDateOnly: DateComponentsConverter.isDateOnly(reminder.dueDateComponents),
      isCompleted: reminder.isCompleted,
      completionDate: reminder.completionDate,
      priority: reminder.priority,
      alarms: (reminder.alarms ?? []).map(alarmRecord),
      recurrenceRules: (reminder.recurrenceRules ?? []).map(recurrenceRecord),
      attendees: (reminder.attendees ?? []).map(participantRecord),
      creationDate: reminder.creationDate,
      lastModifiedDate: reminder.lastModifiedDate
    )
  }

  func alarmRecord(_ alarm: EKAlarm) -> AlarmRecord {
    AlarmRecord(
      type: alarmTypeName(alarm.type),
      relativeOffsetSeconds: alarm.absoluteDate == nil ? alarm.relativeOffset : nil,
      absoluteDate: alarm.absoluteDate,
      proximity: proximityName(alarm.proximity),
      structuredLocation: structuredLocationRecord(alarm.structuredLocation),
      emailAddress: alarm.emailAddress,
      soundName: alarm.soundName
    )
  }

  func recurrenceRecord(_ rule: EKRecurrenceRule) -> RecurrenceRecord {
    let end: RecurrenceEndRecord?
    if let recurrenceEnd = rule.recurrenceEnd {
      end = RecurrenceEndRecord(
        date: recurrenceEnd.endDate,
        occurrenceCount: recurrenceEnd.occurrenceCount > 0
          ? recurrenceEnd.occurrenceCount
          : nil
      )
    } else {
      end = nil
    }
    return RecurrenceRecord(
      frequency: recurrenceFrequencyName(rule.frequency),
      interval: rule.interval,
      daysOfWeek: (rule.daysOfTheWeek ?? []).map {
        RecurrenceWeekdayRecord(
          weekday: weekdayName($0.dayOfTheWeek),
          weekNumber: $0.weekNumber
        )
      },
      daysOfMonth: (rule.daysOfTheMonth ?? []).map(\.intValue),
      monthsOfYear: (rule.monthsOfTheYear ?? []).map(\.intValue),
      weeksOfYear: (rule.weeksOfTheYear ?? []).map(\.intValue),
      daysOfYear: (rule.daysOfTheYear ?? []).map(\.intValue),
      setPositions: (rule.setPositions ?? []).map(\.intValue),
      firstDayOfWeek: rule.firstDayOfTheWeek,
      end: end
    )
  }

  func participantRecord(_ participant: EKParticipant) -> ParticipantRecord {
    ParticipantRecord(
      name: participant.name,
      url: participant.url.absoluteString,
      role: participantRoleName(participant.participantRole),
      type: participantTypeName(participant.participantType),
      status: participantStatusName(participant.participantStatus),
      isCurrentUser: participant.isCurrentUser
    )
  }

  func makeAlarm(_ spec: AlarmSpec) -> EKAlarm {
    switch spec {
    case .relative(let offset):
      return EKAlarm(relativeOffset: offset)
    case .absolute(let date):
      return EKAlarm(absoluteDate: date)
    case .location(let proximity, let spec):
      let alarm = EKAlarm(relativeOffset: 0)
      alarm.proximity = proximity == .enter ? .enter : .leave
      alarm.structuredLocation = makeStructuredLocation(spec)
      return alarm
    }
  }

  func makeStructuredLocation(_ spec: StructuredLocationSpec) -> EKStructuredLocation {
    let location = EKStructuredLocation(title: spec.title)
    location.geoLocation = CLLocation(
      latitude: spec.latitude,
      longitude: spec.longitude
    )
    location.radius = spec.radiusMeters
    return location
  }

  func makeRecurrenceRule(_ spec: RecurrenceSpec) -> EKRecurrenceRule {
    let recurrenceEnd: EKRecurrenceEnd?
    switch spec.end {
    case .date(let date):
      recurrenceEnd = EKRecurrenceEnd(end: date)
    case .count(let count):
      recurrenceEnd = EKRecurrenceEnd(occurrenceCount: count)
    case nil:
      recurrenceEnd = nil
    }

    return EKRecurrenceRule(
      recurrenceWith: recurrenceFrequency(spec.frequency),
      interval: spec.interval,
      daysOfTheWeek: spec.daysOfWeek.map {
        EKRecurrenceDayOfWeek(
          dayOfTheWeek: eventKitWeekday($0.weekday),
          weekNumber: $0.weekNumber
        )
      },
      daysOfTheMonth: spec.daysOfMonth.map(NSNumber.init),
      monthsOfTheYear: spec.monthsOfYear.map(NSNumber.init),
      weeksOfTheYear: spec.weeksOfYear.map(NSNumber.init),
      daysOfTheYear: spec.daysOfYear.map(NSNumber.init),
      setPositions: spec.setPositions.map(NSNumber.init),
      end: recurrenceEnd
    )
  }

  func structuredLocationRecord(_ location: EKStructuredLocation?) -> StructuredLocationRecord? {
    guard let location else {
      return nil
    }
    return StructuredLocationRecord(
      title: location.title,
      latitude: location.geoLocation?.coordinate.latitude,
      longitude: location.geoLocation?.coordinate.longitude,
      radiusMeters: location.radius
    )
  }

  func normalizedEndDate(_ event: EKEvent) -> Date {
    guard event.isAllDay else {
      return event.endDate
    }
    let timeZone = event.timeZone ?? .current
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents(
      [.hour, .minute, .second],
      from: event.endDate
    )
    if components.hour == 23, components.minute == 59, components.second == 59 {
      return event.endDate.addingTimeInterval(1)
    }
    return event.endDate
  }

  func sourceTypeName(_ value: EKSourceType) -> String {
    switch value {
    case .local: "local"
    case .exchange: "exchange"
    case .calDAV: "caldav"
    case .mobileMe: "mobileme"
    case .subscribed: "subscribed"
    case .birthdays: "birthdays"
    @unknown default: "unknown"
    }
  }

  func calendarTypeName(_ value: EKCalendarType) -> String {
    switch value {
    case .local: "local"
    case .calDAV: "caldav"
    case .exchange: "exchange"
    case .subscription: "subscription"
    case .birthday: "birthday"
    @unknown default: "unknown"
    }
  }

  func availabilityName(_ value: EKEventAvailability) -> String {
    switch value {
    case .notSupported: "not-supported"
    case .busy: "busy"
    case .free: "free"
    case .tentative: "tentative"
    case .unavailable: "unavailable"
    @unknown default: "unknown"
    }
  }

  func availability(_ value: EventAvailabilityValue) -> EKEventAvailability {
    switch value {
    case .busy: .busy
    case .free: .free
    case .tentative: .tentative
    case .unavailable: .unavailable
    }
  }

  func eventStatusName(_ value: EKEventStatus) -> String {
    switch value {
    case .none: "none"
    case .confirmed: "confirmed"
    case .tentative: "tentative"
    case .canceled: "canceled"
    @unknown default: "unknown"
    }
  }

  func alarmTypeName(_ value: EKAlarmType) -> String {
    switch value {
    case .display: "display"
    case .audio: "audio"
    case .procedure: "procedure"
    case .email: "email"
    @unknown default: "unknown"
    }
  }

  func proximityName(_ value: EKAlarmProximity) -> String {
    switch value {
    case .none: "none"
    case .enter: "enter"
    case .leave: "leave"
    @unknown default: "unknown"
    }
  }

  func recurrenceFrequencyName(_ value: EKRecurrenceFrequency) -> String {
    switch value {
    case .daily: "daily"
    case .weekly: "weekly"
    case .monthly: "monthly"
    case .yearly: "yearly"
    @unknown default: "unknown"
    }
  }

  func recurrenceFrequency(_ value: RecurrenceFrequency) -> EKRecurrenceFrequency {
    switch value {
    case .daily: .daily
    case .weekly: .weekly
    case .monthly: .monthly
    case .yearly: .yearly
    }
  }

  func weekdayName(_ value: EKWeekday) -> String {
    switch value {
    case .sunday: "sun"
    case .monday: "mon"
    case .tuesday: "tue"
    case .wednesday: "wed"
    case .thursday: "thu"
    case .friday: "fri"
    case .saturday: "sat"
    @unknown default: "unknown"
    }
  }

  func eventKitWeekday(_ value: Weekday) -> EKWeekday {
    switch value {
    case .sunday: .sunday
    case .monday: .monday
    case .tuesday: .tuesday
    case .wednesday: .wednesday
    case .thursday: .thursday
    case .friday: .friday
    case .saturday: .saturday
    }
  }

  func participantRoleName(_ value: EKParticipantRole) -> String {
    switch value {
    case .unknown: "unknown"
    case .required: "required"
    case .optional: "optional"
    case .chair: "chair"
    case .nonParticipant: "non-participant"
    @unknown default: "unknown"
    }
  }

  func participantTypeName(_ value: EKParticipantType) -> String {
    switch value {
    case .unknown: "unknown"
    case .person: "person"
    case .room: "room"
    case .resource: "resource"
    case .group: "group"
    @unknown default: "unknown"
    }
  }

  func participantStatusName(_ value: EKParticipantStatus) -> String {
    switch value {
    case .unknown: "unknown"
    case .pending: "pending"
    case .accepted: "accepted"
    case .declined: "declined"
    case .tentative: "tentative"
    case .delegated: "delegated"
    case .completed: "completed"
    case .inProcess: "in-process"
    @unknown default: "unknown"
    }
  }
}
