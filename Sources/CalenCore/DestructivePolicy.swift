import Foundation

public enum DestructiveDecision: Equatable, Sendable {
  case proceed
  case confirm
}

public enum DestructivePolicy {
  public static func decision(
    force: Bool,
    dryRun: Bool,
    isInteractive: Bool
  ) throws -> DestructiveDecision {
    if force || dryRun {
      return .proceed
    }
    if isInteractive {
      return .confirm
    }
    throw CalenError.invalidInput(
      "Refusing a destructive action without confirmation in noninteractive mode. Pass --force or --dry-run."
    )
  }
}
