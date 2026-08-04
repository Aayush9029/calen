import Foundation

public enum ValueTools {
  @discardableResult
  public static func assign<Value: Equatable>(_ value: Value, to target: inout Value) -> Bool {
    guard target != value else {
      return false
    }
    target = value
    return true
  }

  @discardableResult
  public static func assignOptional<Value: Equatable>(
    _ change: FieldChange<Value>,
    to target: inout Value?
  ) -> Bool {
    switch change {
    case .unchanged:
      return false
    case .set(let value):
      return assign(value, to: &target)
    case .clear:
      guard target != nil else {
        return false
      }
      target = nil
      return true
    }
  }

  public static func validateURL(_ value: String) throws -> URL {
    guard let url = URL(string: value), let scheme = url.scheme, !scheme.isEmpty else {
      throw CalenError.invalidInput(
        "Invalid URL “\(value)”. Include a scheme such as https://."
      )
    }
    return url
  }

  public static func requireNonempty(_ value: String, name: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw CalenError.invalidInput("\(name) cannot be empty.")
    }
    return trimmed
  }
}
