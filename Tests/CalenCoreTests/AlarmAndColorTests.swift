import XCTest

@testable import CalenCore

final class AlarmAndColorTests: XCTestCase {
  func testParsesLocationAlarm() throws {
    let alarm = try AlarmParser.location("enter,53.5461,-113.4938,150,Office")
    guard case .location(let proximity, let location) = alarm else {
      return XCTFail("Expected a location alarm")
    }

    XCTAssertEqual(proximity, .enter)
    XCTAssertEqual(location.title, "Office")
    XCTAssertEqual(location.latitude, 53.5461, accuracy: 0.0001)
    XCTAssertEqual(location.radiusMeters, 150)
  }

  func testRejectsInvalidLocationAlarm() {
    XCTAssertThrowsError(try AlarmParser.location("enter,200,0,10,Nowhere"))
    XCTAssertThrowsError(try AlarmParser.location("arrive,0,0,10,Home"))
  }

  func testParsesAndFormatsColors() throws {
    XCTAssertEqual(try CalendarColor(hex: "#4F8EF7").hex, "#4F8EF7")
    XCTAssertEqual(try CalendarColor(hex: "4F8EF780").hex, "#4F8EF780")
  }

  func testColorComparisonAllowsEventKitNormalization() throws {
    let first = try CalendarColor(red: 0.5, green: 0.25, blue: 0.75)
    let normalized = try CalendarColor(red: 0.504, green: 0.254, blue: 0.746)

    XCTAssertTrue(first.approximatelyEquals(normalized))
  }
}
