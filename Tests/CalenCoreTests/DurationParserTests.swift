import XCTest

@testable import CalenCore

final class DurationParserTests: XCTestCase {
  func testParsesCombinedDurations() throws {
    XCTAssertEqual(try DurationParser.parse("1h30m"), 5_400)
    XCTAssertEqual(try DurationParser.parse("2d4h"), 187_200)
    XCTAssertEqual(try DurationParser.parse("-15m"), -900)
    XCTAssertEqual(try DurationParser.parse("0.5h"), 1_800)
  }

  func testRejectsUnitlessAndUnknownDurations() {
    XCTAssertThrowsError(try DurationParser.parse("15"))
    XCTAssertThrowsError(try DurationParser.parse("1month"))
    XCTAssertThrowsError(try DurationParser.parse(""))
  }
}
