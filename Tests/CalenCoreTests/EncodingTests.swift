import Foundation
import XCTest

@testable import CalenCore

final class EncodingTests: XCTestCase {
  func testMutationEncodingHasStableEnvelope() throws {
    let source = SourceRecord(
      identifier: "source-id",
      title: "Local",
      type: "local",
      isDelegate: false,
      eventCalendarCount: 1,
      reminderListCount: 2
    )
    let mutation = MutationRecord(
      operation: "create",
      changed: true,
      dryRun: false,
      value: source
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let object =
      try JSONSerialization.jsonObject(
        with: encoder.encode(mutation)
      ) as? [String: Any]

    XCTAssertEqual(object?["operation"] as? String, "create")
    XCTAssertEqual(object?["changed"] as? Bool, true)
    XCTAssertEqual(object?["dryRun"] as? Bool, false)
    XCTAssertNotNil(object?["value"] as? [String: Any])
  }

  func testEmptyResultsEncodeAsArray() throws {
    let data = try JSONEncoder().encode([EventRecord]())
    XCTAssertEqual(String(decoding: data, as: UTF8.self), "[]")
  }
}
