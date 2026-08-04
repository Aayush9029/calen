import XCTest

@testable import CalenCore

final class PolicyAndValueTests: XCTestCase {
  func testDestructivePolicyNeverPromptsAutomation() throws {
    XCTAssertEqual(
      try DestructivePolicy.decision(force: true, dryRun: false, isInteractive: false),
      .proceed
    )
    XCTAssertEqual(
      try DestructivePolicy.decision(force: false, dryRun: true, isInteractive: false),
      .proceed
    )
    XCTAssertThrowsError(
      try DestructivePolicy.decision(force: false, dryRun: false, isInteractive: false)
    )
  }

  func testDestructivePolicyPromptsTTY() throws {
    XCTAssertEqual(
      try DestructivePolicy.decision(force: false, dryRun: false, isInteractive: true),
      .confirm
    )
  }

  func testNoOpAssignmentDoesNotReportChange() {
    var value = "same"
    XCTAssertFalse(ValueTools.assign("same", to: &value))
    XCTAssertTrue(ValueTools.assign("different", to: &value))
    XCTAssertEqual(value, "different")
  }

  func testOptionalFieldChanges() {
    var value: String? = "notes"
    XCTAssertFalse(ValueTools.assignOptional(.unchanged, to: &value))
    XCTAssertFalse(ValueTools.assignOptional(.set("notes"), to: &value))
    XCTAssertTrue(ValueTools.assignOptional(.clear, to: &value))
    XCTAssertNil(value)
  }

  func testURLRequiresScheme() {
    XCTAssertThrowsError(try ValueTools.validateURL("example.com"))
    XCTAssertNoThrow(try ValueTools.validateURL("https://example.com"))
  }
}
