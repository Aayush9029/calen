@preconcurrency import EventKit
import XCTest

@testable import CalenCore

@MainActor
final class EventKitAdapterTests: XCTestCase {
  func testMapsWritableAndReadOnlyEventFields() throws {
    let store = EKEventStore()
    let service = EventKitService(eventStore: store)
    let event = EKEvent(eventStore: store)
    event.title = "Review"
    event.startDate = Date(timeIntervalSince1970: 1_800_000_000)
    event.endDate = Date(timeIntervalSince1970: 1_800_003_600)
    event.notes = "Bring notes"
    event.url = URL(string: "https://example.com")
    event.isAllDay = false
    event.alarms = [EKAlarm(relativeOffset: -900)]

    let record = service.eventRecord(event)

    XCTAssertEqual(record.title, "Review")
    XCTAssertEqual(record.notes, "Bring notes")
    XCTAssertEqual(record.url, "https://example.com")
    XCTAssertEqual(record.alarms.first?.relativeOffsetSeconds, -900)
    XCTAssertNil(record.travelTimeSeconds)
    XCTAssertFalse(record.travelTimeWritable)
  }

  func testRecurrenceRoundTripThroughAdapter() throws {
    let service = EventKitService(eventStore: EKEventStore())
    let spec = try RecurrenceSpec(
      frequency: .weekly,
      interval: 2,
      daysOfWeek: [
        WeekdaySpec(weekday: .monday),
        WeekdaySpec(weekday: .friday),
      ],
      end: .count(5)
    )

    let record = service.recurrenceRecord(service.makeRecurrenceRule(spec))

    XCTAssertEqual(record.frequency, "weekly")
    XCTAssertEqual(record.interval, 2)
    XCTAssertEqual(record.daysOfWeek.map(\.weekday), ["mon", "fri"])
    XCTAssertEqual(record.end?.occurrenceCount, 5)
  }

  func testAlarmRoundTripThroughAdapter() throws {
    let service = EventKitService(eventStore: EKEventStore())
    let location = try StructuredLocationSpec(
      title: "Office",
      latitude: 53.5461,
      longitude: -113.4938,
      radiusMeters: 100
    )

    let record = service.alarmRecord(
      service.makeAlarm(.location(.leave, location))
    )

    XCTAssertEqual(record.proximity, "leave")
    XCTAssertEqual(record.structuredLocation?.title, "Office")
    XCTAssertEqual(
      try XCTUnwrap(record.structuredLocation?.latitude),
      53.5461,
      accuracy: 0.0001
    )
  }
}
