import Foundation

public enum CalenError: LocalizedError, Equatable, Sendable {
  case ambiguous(String, matches: [String])
  case authorizationDenied(String)
  case authorizationRestricted(String)
  case invalidInput(String)
  case notFound(String)
  case platformLimitation(String)
  case readOnly(String)
  case unsupported(String)

  public var errorDescription: String? {
    switch self {
    case .ambiguous(let value, let matches):
      "“\(value)” matches multiple items: \(matches.joined(separator: ", ")). Use an identifier."
    case .authorizationDenied(let entity):
      "\(entity) access is denied. Open System Settings > Privacy & Security > \(entity), then enable calen for your terminal."
    case .authorizationRestricted(let entity):
      "\(entity) access is restricted by system policy and cannot be changed by calen."
    case .invalidInput(let message):
      message
    case .notFound(let message):
      message
    case .platformLimitation(let message):
      message
    case .readOnly(let message):
      message
    case .unsupported(let message):
      message
    }
  }
}
