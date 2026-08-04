import XCTest

@testable import CalenCore

final class RecurrenceTests: XCTestCase {
  func testParsesWeekdaysWithOrdinals() throws {
    XCTAssertEqual(
      try RecurrenceParser.weekdays("mon,2tue,-1fri"),
      [
        WeekdaySpec(weekday: .monday),
        WeekdaySpec(weekday: .tuesday, weekNumber: 2),
        WeekdaySpec(weekday: .friday, weekNumber: -1),
      ]
    )
  }

  func testBuildsAdvancedRecurrence() throws {
    let spec = try RecurrenceSpec(
      frequency: .monthly,
      interval: 2,
      daysOfWeek: [WeekdaySpec(weekday: .friday)],
      setPositions: [-1],
      end: .count(12)
    )

    XCTAssertEqual(spec.frequency, .monthly)
    XCTAssertEqual(spec.interval, 2)
    XCTAssertEqual(spec.setPositions, [-1])
    XCTAssertEqual(spec.end, .count(12))
  }

  func testRejectsInvalidRecurrenceValues() {
    XCTAssertThrowsError(
      try RecurrenceSpec(frequency: .daily, interval: 0)
    )
    XCTAssertThrowsError(
      try RecurrenceSpec(frequency: .monthly, daysOfMonth: [0])
    )
    XCTAssertThrowsError(
      try RecurrenceSpec(frequency: .yearly, monthsOfYear: [13])
    )
    XCTAssertThrowsError(
      try RecurrenceSpec(frequency: .weekly, end: .count(0))
    )
  }

  func testRejectsInvalidWeekday() {
    XCTAssertThrowsError(try RecurrenceParser.weekdays("monday"))
    XCTAssertThrowsError(try RecurrenceParser.weekdays("0mon"))
  }
}
