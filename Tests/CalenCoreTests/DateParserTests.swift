import XCTest

@testable import CalenCore

final class DateParserTests: XCTestCase {
  func testParsesExplicitISO8601Offset() throws {
    let parser = DateParser(timeZone: TimeZone(identifier: "America/Edmonton")!)
    let parsed = try parser.parse("2026-08-05T09:30:00-06:00")

    XCTAssertFalse(parsed.isDateOnly)
    XCTAssertEqual(parsed.date.timeIntervalSince1970, 1_785_943_800, accuracy: 0.1)
  }

  func testParsesDateOnlyAtLocalMidnight() throws {
    let zone = TimeZone(identifier: "America/Edmonton")!
    let parser = DateParser(timeZone: zone)
    let parsed = try parser.parse("2026-08-05")
    let components = parser.calendar.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: parsed.date
    )

    XCTAssertTrue(parsed.isDateOnly)
    XCTAssertEqual(components.year, 2026)
    XCTAssertEqual(components.month, 8)
    XCTAssertEqual(components.day, 5)
    XCTAssertEqual(components.hour, 0)
    XCTAssertEqual(components.minute, 0)
  }

  func testRejectsNonexistentDaylightSavingTime() throws {
    let parser = DateParser(timeZone: TimeZone(identifier: "America/Edmonton")!)

    XCTAssertThrowsError(try parser.parse("2026-03-08 02:30")) { error in
      XCTAssertTrue(error.localizedDescription.contains("does not exist"))
    }
  }

  func testRejectsUnknownTimeZone() {
    XCTAssertThrowsError(try DateParser.timeZone(named: "Moon/Tranquility"))
  }

  func testDateComponentsPreserveDateOnlyBehavior() throws {
    let parsed = try DateParser(
      timeZone: TimeZone(identifier: "America/Edmonton")!
    ).parse("2026-12-25")
    let components = DateComponentsConverter.components(from: parsed)

    XCTAssertTrue(DateComponentsConverter.isDateOnly(components))
    XCTAssertEqual(DateComponentsConverter.date(from: components), parsed.date)
  }
}
